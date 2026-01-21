import AppKit
import SwiftUI

final class QuickDirectorySettingsViewModel: ObservableObject {
    @Published var entries: [QuickDirectoryEntry]
    @Published private var aliasInputs: [UUID: String]

    init(entries: [QuickDirectoryEntry] = QuickDirectoryPreferences.entries()) {
        self.entries = entries
        aliasInputs = Dictionary(uniqueKeysWithValues: entries.map { ($0.id, $0.alias ?? "") })
    }

    func addDirectory(url: URL) {
        let normalizedPath = QuickDirectoryPreferences.normalize(url.path)
        var updated = entries
        if let index = updated.firstIndex(where: { $0.normalizedPath == normalizedPath }) {
            if updated[index].name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                updated[index].name = url.lastPathComponent
            }
        } else {
            let entry = QuickDirectoryEntry(
                id: UUID(),
                path: normalizedPath,
                name: url.lastPathComponent,
                alias: nil,
                isDefault: false
            )
            updated.append(entry)
        }
        persist(updated)
    }

    func removeEntry(_ entry: QuickDirectoryEntry) {
        var updated = entries
        updated.removeAll { $0.id == entry.id }
        persist(updated)
    }

    func bindingForAlias(of entry: QuickDirectoryEntry) -> Binding<String> {
        Binding(
            get: { [weak self] in
                self?.aliasInputs[entry.id] ?? entry.alias ?? ""
            },
            set: { [weak self] newValue in
                self?.aliasInputs[entry.id] = newValue
                self?.updateAlias(for: entry, alias: newValue)
            }
        )
    }

    func subtitle(for entry: QuickDirectoryEntry) -> String {
        let home = NSHomeDirectory()
        if entry.path.hasPrefix(home) {
            return entry.path.replacingOccurrences(of: home, with: "~")
        }
        return entry.path
    }

    private func updateAlias(for entry: QuickDirectoryEntry, alias: String) {
        var updated = entries
        guard let index = updated.firstIndex(where: { $0.id == entry.id }) else { return }
        let trimmed = alias.trimmingCharacters(in: .whitespacesAndNewlines)
        updated[index].alias = trimmed.isEmpty ? nil : trimmed
        persist(updated)
    }

    private func persist(_ entries: [QuickDirectoryEntry]) {
        QuickDirectoryPreferences.save(entries)
        let snapshot = QuickDirectoryPreferences.entries()
        self.entries = snapshot
        aliasInputs = Dictionary(uniqueKeysWithValues: snapshot.map { ($0.id, $0.alias ?? "") })
    }
}

struct QuickDirectorySettingsView: View {
    @StateObject var viewModel: QuickDirectorySettingsViewModel
    let onSaved: (() -> Void)?

    init(viewModel: QuickDirectorySettingsViewModel, onSaved: (() -> Void)? = nil) {
        self._viewModel = StateObject(wrappedValue: viewModel)
        self.onSaved = onSaved
    }

    var body: some View {
        VStack(spacing: SettingsLayout.sectionSpacing) {
            SettingsSection("快捷目录", note: "通过 \"/\" 触发快速目录搜索，别名可作为搜索关键字。") {
                VStack(alignment: .leading, spacing: 10) {
                    if viewModel.entries.isEmpty {
                        Text("暂无快捷目录")
                            .font(.system(size: 11))
                            .foregroundColor(.secondary)
                    } else {
                        ForEach(viewModel.entries, id: \.id) { entry in
                            let aliasBinding = viewModel.bindingForAlias(of: entry)
                            HStack(alignment: .center, spacing: 12) {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text(entry.displayTitle)
                                        .font(.system(size: 13, weight: .semibold))
                                    Text(viewModel.subtitle(for: entry))
                                        .font(.system(size: 11))
                                        .foregroundColor(.secondary)
                                }
                                Spacer(minLength: 0)
                                TextField("别名", text: aliasBinding)
                                    .textFieldStyle(.roundedBorder)
                                    .frame(width: 160)
                                    .onChange(of: aliasBinding.wrappedValue) { _ in
                                        onSaved?()
                                    }
                                Button {
                                    viewModel.removeEntry(entry)
                                    onSaved?()
                                } label: {
                                    Image(systemName: "trash")
                                }
                                .buttonStyle(.borderless)
                            }
                        }
                    }
                    HStack(spacing: 8) {
                        Button("添加目录…") {
                            pickDirectory()
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                    }
                }
            }
        }
        .padding(.horizontal, SettingsLayout.horizontalPadding)
        .padding(.top, SettingsLayout.topPadding)
        .padding(.bottom, SettingsLayout.bottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private func pickDirectory() {
        let panel = NSOpenPanel()
        panel.canChooseDirectories = true
        panel.canChooseFiles = false
        panel.allowsMultipleSelection = false
        panel.canCreateDirectories = false
        panel.begin { response in
            guard response == .OK, let url = panel.url else { return }
            viewModel.addDirectory(url: url)
            onSaved?()
        }
    }
}
