import AppKit
import SwiftUI

@MainActor
final class AppIndexSettingsViewModel: ObservableObject {
    @Published var apps: [AppIndex.AppEntry] = []
    @Published var aliasText: [String: String] = [:]

    private let appIndex = AppIndex.shared
    private let aliasStore: UserAliasStore
    private var pendingSave: DispatchWorkItem?

    init(aliasStore: UserAliasStore = UserAliasStore(fileURL: AppIndex.aliasFileURL())) {
        self.aliasStore = aliasStore
    }

    func load() {
        Task {
            await reload()
        }
    }

    func refreshIndex() {
        Task {
            await appIndex.rebuild()
            await reload()
        }
    }

    private func reload() async {
        let snapshot = await appIndex.snapshot()
        let payload = aliasStore.snapshot()
        let aliases = payload.byBundleID
        await MainActor.run {
            self.apps = snapshot
            self.aliasText = aliases.reduce(into: [:]) { result, pair in
                result[pair.key] = pair.value.joined(separator: ", ")
            }
        }
    }

    func updateAlias(for bundleID: String, text: String) {
        aliasText[bundleID] = text
        pendingSave?.cancel()
        let workItem = DispatchWorkItem { [weak self] in
            self?.saveAlias(bundleID: bundleID, text: text)
        }
        pendingSave = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.4, execute: workItem)
    }

    private func saveAlias(bundleID: String, text: String) {
        let aliases = text
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        aliasStore.setAliases(bundleID: bundleID, aliases: aliases)
        Task { await appIndex.refreshAliases() }
    }
}

struct AppIndexSettingsView: View {
    @StateObject var viewModel: AppIndexSettingsViewModel

    var body: some View {
        VStack(spacing: SettingsLayout.sectionSpacing) {
            header
                .padding(.bottom, SettingsLayout.headerBottomPadding)

            SettingsSection {
                Table(viewModel.apps) {
                    TableColumn("App 名称") { entry in
                        HStack(spacing: 8) {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: entry.path))
                                .resizable()
                                .frame(width: 18, height: 18)
                            Text(entry.name)
                                .lineLimit(1)
                                .truncationMode(.tail)
                        }
                    }
                    TableColumn("路径") { entry in
                        Text(entry.path)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    TableColumn("别名") { entry in
                        aliasEditor(for: entry)
                    }
                }
                .frame(minHeight: 320)
            }
        }
        .padding(.horizontal, SettingsLayout.horizontalPadding)
        .padding(.top, SettingsLayout.topPadding)
        .padding(.bottom, SettingsLayout.bottomPadding)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .onAppear {
            viewModel.load()
        }
    }

    private var header: some View {
        HStack(alignment: .firstTextBaseline) {
            VStack(alignment: .leading, spacing: 4) {
                Text("应用索引")
                    .font(.system(size: 20, weight: .semibold))
                Text("维护应用别名，优化搜索命中。")
                    .font(.system(size: 12))
                    .foregroundColor(.secondary)
            }
            Spacer()
            Button("刷新索引") {
                viewModel.refreshIndex()
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func aliasEditor(for entry: AppIndex.AppEntry) -> some View {
        if let bundleID = entry.bundleID {
            let binding = Binding<String>(
                get: { viewModel.aliasText[bundleID] ?? "" },
                set: { viewModel.updateAlias(for: bundleID, text: $0) }
            )
            TextField("别名（逗号分隔）", text: binding)
                .textFieldStyle(.roundedBorder)
        } else {
            Text("无 bundleID")
                .foregroundColor(.secondary)
        }
    }
}
