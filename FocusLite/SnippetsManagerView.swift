import SwiftUI

@MainActor
final class SnippetsManagerViewModel: ObservableObject {
    @Published var snippets: [Snippet] = []
    @Published var editorDraft: SnippetDraft?
    @Published var isLoading = false
    @Published var searchPrefixText: String

    private let store: SnippetStore

    init(store: SnippetStore = .shared) {
        self.store = store
        self.searchPrefixText = SnippetsPreferences.searchPrefix
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

    var body: some View {
        VStack(spacing: 12) {
            header
            prefixSettings

            if viewModel.snippets.isEmpty {
                emptyState
            } else {
                List {
                    ForEach(viewModel.snippets) { snippet in
                        SnippetRow(snippet: snippet,
                                   onEdit: { viewModel.editSnippet(snippet) },
                                   onDelete: { viewModel.deleteSnippet(snippet) })
                    }
                    .onDelete(perform: viewModel.delete)
                }
                .listStyle(.inset)
            }
        }
        .padding(16)
        .frame(width: 560, height: 460)
        .onAppear {
            viewModel.load()
        }
        .sheet(item: $viewModel.editorDraft) { draft in
            SnippetEditorView(
                draft: draft,
                onSave: { viewModel.save(draft: $0) },
                onCancel: { viewModel.dismissEditor() }
            )
        }
    }

    private var header: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("片段")
                    .font(.system(size: 20, weight: .semibold))
                Text("管理文本快捷输入与模板。")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }

            Spacer()

            Button {
                viewModel.addSnippet()
            } label: {
                Image(systemName: "plus")
            }
            .buttonStyle(.borderedProminent)
        }
    }

    private var prefixSettings: some View {
        HStack(spacing: 8) {
            Text("搜索前缀")
                .font(.system(size: 12, weight: .medium))
                .foregroundColor(.secondary)
            TextField("如 sn", text: $viewModel.searchPrefixText)
                .textFieldStyle(.roundedBorder)
                .frame(width: 120)
                .onSubmit {
                    viewModel.saveSearchPrefix()
                }
                .onChange(of: viewModel.searchPrefixText) { _ in
                    viewModel.saveSearchPrefix()
                }
            Spacer()
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

    var body: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text(snippet.title)
                    .font(.system(size: 14, weight: .semibold))

                HStack(spacing: 8) {
                    if !snippet.keyword.isEmpty {
                        Text(";" + snippet.keyword)
                            .font(.system(size: 12, weight: .medium))
                            .foregroundColor(.secondary)
                    }

                    if !snippet.tags.isEmpty {
                        Text(snippet.tags.joined(separator: ", "))
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    }
                }
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
    }
}

private struct SnippetEditorView: View {
    @State var draft: SnippetDraft
    let onSave: (SnippetDraft) -> Void
    let onCancel: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Form {
                TextField("标题", text: $draft.title)
                TextField("关键词（可选，不含 ;）", text: $draft.keyword)
                TextField("标签（逗号分隔）", text: $draft.tagsText)

                VStack(alignment: .leading, spacing: 8) {
                    Text("内容")
                        .font(.system(size: 12, weight: .medium))
                        .foregroundColor(.secondary)
                    TextEditor(text: $draft.content)
                        .frame(minHeight: 140)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(Color(nsColor: .separatorColor), lineWidth: 1)
                        )
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
}
