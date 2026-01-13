import AppKit
import SwiftUI

@MainActor
final class AppIndexSettingsViewModel: ObservableObject {
    @Published var apps: [AppIndex.AppEntry] = []
    @Published var aliasText: [String: String] = [:]
    @Published var searchText: String = ""
    @Published var excludedBundleIDs: Set<String> = []
    @Published var excludedPaths: Set<String> = []

    private let appIndex = AppIndex.shared
    private let aliasStore: UserAliasStore
    private var pendingSave: DispatchWorkItem?
    private var allApps: [AppIndex.AppEntry] = []
    private let iconCache = NSCache<NSString, NSImage>()

    init(aliasStore: UserAliasStore = UserAliasStore(fileURL: AppIndex.aliasFileURL())) {
        self.aliasStore = aliasStore
    }
    
    var filteredApps: [AppIndex.AppEntry] {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return apps }
        return apps.filter { matchesSearch(entry: $0, query: trimmed) }
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
            self.excludedBundleIDs = AppSearchPreferences.excludedBundleIDs
            self.excludedPaths = AppSearchPreferences.excludedPaths
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

    private func matchesSearch(entry: AppIndex.AppEntry, query: String) -> Bool {
        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return true }

        let info = Matcher.queryInfo(for: trimmed)
        if let match = Matcher.match(query: trimmed, index: entry.nameIndex),
           Matcher.shouldInclude(match, info: info) {
            return true
        }

        // 保留路径 / Bundle ID 简单包含匹配，避免与旧逻辑差距过大
        let lowered = trimmed.lowercased()
        if entry.path.lowercased().contains(lowered) {
            return true
        }
        if let bundleID = entry.bundleID?.lowercased(), bundleID.contains(lowered) {
            return true
        }
        return false
    }

    private func saveAlias(bundleID: String, text: String) {
        let aliases = text
            .split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        aliasStore.setAliases(bundleID: bundleID, aliases: aliases)
        Task { await appIndex.refreshAliases() }
    }

    func icon(for path: String) -> NSImage {
        if let cached = iconCache.object(forKey: path as NSString) {
            return cached
        }
        let icon = NSWorkspace.shared.icon(forFile: path)
        iconCache.setObject(icon, forKey: path as NSString)
        return icon
    }

    func isExcluded(_ entry: AppIndex.AppEntry) -> Bool {
        AppSearchPreferences.isExcluded(
            bundleID: entry.bundleID,
            path: entry.path,
            excludedBundleIDs: excludedBundleIDs,
            excludedPaths: excludedPaths
        )
    }

    func setExcluded(_ entry: AppIndex.AppEntry, isExcluded: Bool) {
        if let bundleID = entry.bundleID {
            var updated = excludedBundleIDs
            if isExcluded {
                updated.insert(bundleID)
            } else {
                updated.remove(bundleID)
            }
            excludedBundleIDs = updated
            AppSearchPreferences.excludedBundleIDs = updated
            return
        }

        var updated = excludedPaths
        if isExcluded {
            updated.insert(entry.path)
        } else {
            updated.remove(entry.path)
        }
        excludedPaths = updated
        AppSearchPreferences.excludedPaths = updated
    }
}

struct AppIndexSettingsView: View {
    @StateObject var viewModel: AppIndexSettingsViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // 搜索框
            HStack {
                Image(systemName: "magnifyingglass")
                    .foregroundColor(.secondary)
                TextField("搜索应用名称、路径或 Bundle ID", text: $viewModel.searchText)
                    .textFieldStyle(.roundedBorder)
                if !viewModel.searchText.isEmpty {
                    Button(action: { viewModel.searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .foregroundColor(.secondary)
                    }
                    .buttonStyle(.plain)
                }
                Spacer()
                if !viewModel.searchText.isEmpty {
                    Text("\(viewModel.filteredApps.count) 个结果")
                        .foregroundColor(.secondary)
                }
                Button("刷新索引") {
                    viewModel.refreshIndex()
                }
                .buttonStyle(.bordered)
            }
            .padding(.horizontal, SettingsLayout.horizontalPadding + 4)
            .padding(.top, SettingsLayout.topPadding + 8)
            .padding(.bottom, 12)

            // 表格区域，充满剩余高度
            Table(viewModel.filteredApps) {
                TableColumn("App 名称") { entry in
                    HStack(spacing: 8) {
                        Image(nsImage: viewModel.icon(for: entry.path))
                            .resizable()
                            .frame(width: 18, height: 18)
                        Text(entry.name)
                            .lineLimit(1)
                            .truncationMode(.tail)
                            .help(entry.name)
                    }
                }
                .width(ideal: 100)
                TableColumn("路径") { entry in
                    Button {
                        let url = URL(fileURLWithPath: entry.path)
                        NSWorkspace.shared.activateFileViewerSelecting([url])
                    } label: {
                        Text(entry.path)
                            .foregroundColor(.secondary)
                            .lineLimit(1)
                            .truncationMode(.middle)
                    }
                    .buttonStyle(.plain)
                    .help(entry.path)
                }
                .width(ideal: 180)
                TableColumn("排除") { entry in
                    let binding = Binding<Bool>(
                        get: { viewModel.isExcluded(entry) },
                        set: { viewModel.setExcluded(entry, isExcluded: $0) }
                    )
                    Toggle("", isOn: binding)
                        .toggleStyle(.checkbox)
                        .labelsHidden()
                }
                .width(ideal: 30)
                TableColumn("别名") { entry in
                    aliasEditor(for: entry)
                }
                .width(ideal: 100)
            }
            .padding(.horizontal, SettingsLayout.horizontalPadding + 4)
            .padding(.bottom, SettingsLayout.bottomPadding + 8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onAppear {
            viewModel.load()
        }
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
//                .frame(minWidth: 180, idealWidth: 200, maxWidth: .infinity, alignment: .leading)
//                .help(binding.wrappedValue)
        } else {
            Text("无 bundleID")
                .foregroundColor(.secondary)
        }
    }
}
