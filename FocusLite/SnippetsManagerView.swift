import Foundation
import SwiftUI

@MainActor
final class SnippetsManagerViewModel: ObservableObject {
    @Published var snippets: [Snippet] = []
    @Published var editorDraft: SnippetDraft?
    @Published var isLoading = false
    @Published var searchPrefixText: String
    @Published var autoPasteEnabled: Bool
    @Published var hotKeyText: String
    @Published var accessibilityTrusted: Bool

    private let store: SnippetStore

    init(store: SnippetStore = .shared) {
        self.store = store
        self.searchPrefixText = SnippetsPreferences.searchPrefix
        self.autoPasteEnabled = SnippetsPreferences.autoPasteAfterSelect
        self.hotKeyText = SnippetsPreferences.hotKeyText
        self.accessibilityTrusted = AccessibilityPermission.isTrusted(prompt: false)
    }

    func load() {
        guard !isLoading else { return }
        isLoading = true

        Task {
            await refresh()
            await MainActor.run {
                self.isLoading = false
            }
        }
    }

    func refresh() async {
        let items = await store.snapshot()
        snippets = items
    }

    func addSnippet() {
        editorDraft = SnippetDraft()
    }

    func editSnippet(_ snippet: Snippet) {
        editorDraft = SnippetDraft(snippet: snippet)
    }

    func save(draft: SnippetDraft) {
        guard let snippet = draft.toSnippet() else { return }
        Task {
            await store.upsert(snippet)
            await refresh()
            await MainActor.run {
                self.editorDraft = nil
            }
        }
    }

    func dismissEditor() {
        editorDraft = nil
    }

    func delete(at offsets: IndexSet) {
        let targets = offsets.compactMap { index in
            snippets.indices.contains(index) ? snippets[index] : nil
        }

        guard !targets.isEmpty else { return }
        Task {
            for snippet in targets {
                await store.delete(id: snippet.id)
            }
            await refresh()
        }
    }

    func deleteSnippet(_ snippet: Snippet) {
        Task {
            await store.delete(id: snippet.id)
            await refresh()
        }
    }

    func saveSearchPrefix() {
        SnippetsPreferences.searchPrefix = searchPrefixText
    }

    func saveAutoPaste() {
        SnippetsPreferences.autoPasteAfterSelect = autoPasteEnabled
    }

    func saveHotKey() {
        SnippetsPreferences.hotKeyText = hotKeyText
    }

    func ensureAccessibilityForAutoPaste() -> Bool {
        if autoPasteEnabled && !AccessibilityPermission.isTrusted(prompt: false) {
            let granted = AccessibilityPermission.requestIfNeeded()
            if !granted {
                autoPasteEnabled = false
                return false
            }
        }
        return true
    }
}

struct SnippetDraft: Identifiable {
    let id: UUID
    var snippetID: UUID?
    var title: String
    var keyword: String
    var content: String
    var tagsText: String

    init() {
        self.id = UUID()
        self.snippetID = nil
        self.title = ""
        self.keyword = ""
        self.content = ""
        self.tagsText = ""
    }

    init(snippet: Snippet) {
        self.id = UUID()
        self.snippetID = snippet.id
        self.title = snippet.title
        self.keyword = snippet.keyword
        self.content = snippet.content
        self.tagsText = snippet.tags.joined(separator: ", ")
    }

    var isValid: Bool {
        !title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
        !content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    var tags: [String] {
        tagsText
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }

    func toSnippet() -> Snippet? {
        let trimmedTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedTitle.isEmpty, !trimmedContent.isEmpty else { return nil }

        let trimmedKeyword = keyword.trimmingCharacters(in: .whitespacesAndNewlines)
        let normalizedKeyword = trimmedKeyword.hasPrefix(";")
            ? String(trimmedKeyword.dropFirst()).trimmingCharacters(in: .whitespacesAndNewlines)
            : trimmedKeyword

        return Snippet(
            id: snippetID ?? UUID(),
            title: trimmedTitle,
            keyword: normalizedKeyword,
            content: trimmedContent,
            tags: tags
        )
    }
}

struct SnippetsManagerView: View {
    @StateObject var viewModel: SnippetsManagerViewModel
    let onSaved: (() -> Void)?
    @Environment(\.scenePhase) private var scenePhase

    init(viewModel: SnippetsManagerViewModel, onSaved: (() -> Void)? = nil) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self.onSaved = onSaved
    }

    var body: some View {
        VStack(spacing: SettingsLayout.sectionSpacing) {
            SettingsSection(
                "搜索前缀",
                note: "快捷键需包含 ⌘/⌥/⌃ 中至少一个。示例：⌥+Space 或 ⌥+K。"
            ) {
                prefixSettings
            }

            SettingsSection("行为") {
                SettingsFieldRow(title: "自动粘贴") {
                    Toggle("选中后自动粘贴到输入框", isOn: $viewModel.autoPasteEnabled)
                        .toggleStyle(.switch)
                        .onChange(of: viewModel.autoPasteEnabled) { _ in
                            ensureAccessibilityIfNeeded()
                        }
                    if viewModel.autoPasteEnabled && !viewModel.accessibilityTrusted {
                        Text("请检查 FocusLite 的辅助功能权限")
                            .font(.system(size: 11))
                            .foregroundColor(.orange)
                    }
                }
            }

            SettingsSection {
                HStack {
                    Text("片段列表")
                        .font(.system(size: 13, weight: .semibold))
                    Spacer()
                    Button {
                        viewModel.addSnippet()
                    } label: {
                        Image(systemName: "plus")
                    }
                    .buttonStyle(.bordered)
                }

                if viewModel.snippets.isEmpty {
                    emptyState
                } else {
                    List {
                        ForEach(displaySnippets) { snippet in
                            SnippetRow(snippet: snippet,
                                       onEdit: { viewModel.editSnippet(snippet) },
                                       onDelete: { viewModel.deleteSnippet(snippet) })
                        }
                        .onDelete { offsets in
                            let targets = offsets.map { displaySnippets[$0] }
                            for snippet in targets {
                                viewModel.deleteSnippet(snippet)
                            }
                        }
                    }
                    .listStyle(.inset)
                    .frame(minHeight: 240)
                }
            }
        }
        .padding(.horizontal, SettingsLayout.horizontalPadding)
        .padding(.top, SettingsLayout.topPadding)
        .padding(.bottom, SettingsLayout.bottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            viewModel.load()
            refreshPermissionStatus()
        }
        .sheet(item: $viewModel.editorDraft) { draft in
            SnippetEditorView(
                draft: draft,
                onSave: { viewModel.save(draft: $0) },
                onCancel: { viewModel.dismissEditor() }
            )
        }
        .onReceive(NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)) { _ in
            refreshPermissionStatus()
        }
        .onReceive(NotificationCenter.default.publisher(for: .permissionsShouldRefresh)) { _ in
            refreshPermissionStatus()
        }
        .onChange(of: scenePhase) { _ in
            refreshPermissionStatus()
        }
    }

    private var displaySnippets: [Snippet] {
        viewModel.snippets.sorted {
            if $0.updatedAt != $1.updatedAt {
                return $0.updatedAt < $1.updatedAt
            }
            return $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending
        }
    }

    private var prefixSettings: some View {
        VStack(spacing: 12) {
            SettingsFieldRow(title: "搜索前缀") {
                TextField("如 Sn", text: $viewModel.searchPrefixText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 120)
                    .onSubmit {
                        viewModel.saveSearchPrefix()
                        onSaved?()
                    }
                    .onChange(of: viewModel.searchPrefixText) { _ in
                        viewModel.saveSearchPrefix()
                        onSaved?()
                    }
            }

            SettingsFieldRow(title: "快捷键") {
                HotKeyRecorderField(
                    text: $viewModel.hotKeyText,
                    conflictHotKeys: [GeneralPreferences.launcherHotKeyText, ClipboardPreferences.hotKeyText, TranslatePreferences.hotKeyText]
                ) {
                    viewModel.saveHotKey()
                    onSaved?()
                }
            }
        }
    }

    private func ensureAccessibilityIfNeeded() {
        let granted = viewModel.ensureAccessibilityForAutoPaste()
        if granted {
            viewModel.saveAutoPaste()
            onSaved?()
        } else {
            viewModel.saveAutoPaste()
            onSaved?()
        }
    }

    private func refreshPermissionStatus() {
        let trusted = AccessibilityPermission.isTrusted(prompt: false)
        if trusted != viewModel.accessibilityTrusted {
            viewModel.accessibilityTrusted = trusted
        }
    }

    private var emptyState: some View {
        VStack(spacing: 8) {
            Text("还没有片段")
                .font(.system(size: 14, weight: .medium))
            Text("点击 + 添加你的第一个片段。")
                .font(.system(size: 12))
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

private struct SnippetRow: View {
    let snippet: Snippet
    let onEdit: () -> Void
    let onDelete: () -> Void
    @State private var isHovered = false

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 8) {
                    Text(snippet.title)
                        .font(.system(size: 14, weight: .semibold))
                        .lineLimit(1)
                        .truncationMode(.tail)

                    if !snippet.keyword.isEmpty {
                        Text(snippet.keyword)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.tail)
                    }
                }

                Text(snippet.content.replacingOccurrences(of: "\n", with: " "))
                    .font(.system(size: 11))
                    .foregroundColor(.secondary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }

            Spacer()

            Button(action: onEdit) {
                Image(systemName: "pencil")
            }
            .buttonStyle(.borderless)

            Button(action: onDelete) {
                Image(systemName: "trash")
            }
            .buttonStyle(.borderless)
        }
        .padding(.vertical, 4)
        .contentShape(Rectangle())
        .onHover { isHovered = $0 }
        .listRowBackground(
            RoundedRectangle(cornerRadius: 6)
                .fill(isHovered ? Color(nsColor: .selectedContentBackgroundColor).opacity(0.15) : Color.clear)
        )
    }
}

private struct SnippetEditorView: View {
    @State var draft: SnippetDraft
    let onSave: (SnippetDraft) -> Void
    let onCancel: () -> Void
    @State private var formatMessage: String?

    var body: some View {
        VStack(spacing: 16) {
            Form {
                TextField("标题", text: $draft.title)
                TextField("关键词（可选，不含 ;）", text: $draft.keyword)
                TextField("标签（逗号分隔）", text: $draft.tagsText)

                VStack(alignment: .leading, spacing: 8) {
                    HStack {
                        Text("内容")
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                        Spacer()
                        Button("格式化") {
                            formatContent()
                        }
                        .buttonStyle(.bordered)
                    }
                    TextEditor(text: $draft.content)
                        .frame(minHeight: 140)
                        .padding(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
                    if let message = formatMessage {
                        Text(message)
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
                .padding(.vertical, 6)
            }
            .formStyle(.grouped)

            HStack {
                Spacer()

                Button("取消", action: onCancel)

                Button("保存") {
                    onSave(draft)
                }
                .buttonStyle(.borderedProminent)
                .disabled(!draft.isValid)
            }
        }
        .padding(16)
        .frame(width: 560, height: 420)
    }

    private func formatContent() {
        let trimmed = draft.content.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            formatMessage = "内容为空"
            return
        }

        if let data = trimmed.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data),
           let pretty = try? JSONSerialization.data(withJSONObject: json, options: [.prettyPrinted, .sortedKeys]),
           let formatted = String(data: pretty, encoding: .utf8) {
            draft.content = formatted
            formatMessage = "已按 JSON 格式化"
            return
        }

        let cleaned = draft.content
            .split(omittingEmptySubsequences: false, whereSeparator: \.isNewline)
            .map { line in
                line.replacingOccurrences(of: "\\s+$", with: "", options: .regularExpression)
            }
            .joined(separator: "\n")
        draft.content = cleaned
        formatMessage = "已清理行尾空格"
    }
}
