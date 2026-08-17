import AppKit
import SwiftUI

@MainActor
final class AppIndexSettingsViewModel: ObservableObject {
    @Published private(set) var apps: [AppIndex.AppEntry] = []
    @Published var aliasText: [String: String] = [:]
    @Published var searchText: String = "" {
        didSet {
            updateFilteredApps()
        }
    }
    @Published private(set) var filteredApps: [AppIndex.AppEntry] = []
    @Published var excludedBundleIDs: Set<String> = []
    @Published var excludedPaths: Set<String> = []

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
            self.updateFilteredApps()
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

    private func updateFilteredApps() {
        let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            filteredApps = apps
            return
        }

        let info = Matcher.queryInfo(for: trimmed)
        let lowered = trimmed.lowercased()
        filteredApps = apps.filter { matchesSearch(entry: $0, info: info, loweredQuery: lowered) }
    }

    private func matchesSearch(entry: AppIndex.AppEntry, info: QueryInfo, loweredQuery: String) -> Bool {
        if let match = Matcher.match(info: info, index: entry.nameIndex),
           Matcher.shouldInclude(match, info: info) {
            return true
        }

        // 保留路径 / Bundle ID 简单包含匹配，避免与旧逻辑差距过大
        if entry.path.lowercased().contains(loweredQuery) {
            return true
        }
        if let bundleID = entry.bundleID?.lowercased(), bundleID.contains(loweredQuery) {
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
                        AppIndexIconView(path: entry.path)
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

private struct AppIndexIconView: View {
    let path: String

    @State private var icon: CGImage?

    var body: some View {
        Group {
            if let icon {
                Image(decorative: icon, scale: 2)
                    .resizable()
            } else {
                Image(systemName: "app.dashed")
                    .resizable()
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 18, height: 18)
        .task(id: path) {
            icon = await AppIndexIconStore.shared.icon(for: path)
        }
    }
}

@MainActor
private final class AppIndexIconStore {
    static let shared = AppIndexIconStore()

    private let cache = NSCache<NSString, CGImage>()
    private var inFlight: [String: Task<AppIndexIconResult, Never>] = [:]

    private init() {
        cache.countLimit = 256
    }

    func icon(for path: String) async -> CGImage? {
        if let cached = cache.object(forKey: path as NSString) {
            return cached
        }

        if let task = inFlight[path] {
            return await task.value.image
        }

        let task = Task {
            await AppIndexIconWorkQueue.shared.load(path: path)
        }
        inFlight[path] = task

        let result = await task.value
        inFlight[path] = nil
        if let image = result.image {
            cache.setObject(image, forKey: path as NSString)
        }
        return result.image
    }
}

private final class AppIndexIconResult: @unchecked Sendable {
    let image: CGImage?

    init(image: CGImage?) {
        self.image = image
    }
}

private final class AppIndexIconWorkQueue: @unchecked Sendable {
    static let shared = AppIndexIconWorkQueue()

    private let queue: OperationQueue = {
        let queue = OperationQueue()
        queue.name = "com.focuslite.app-index-icons"
        queue.qualityOfService = .utility
        queue.maxConcurrentOperationCount = 3
        return queue
    }()

    private init() {}

    func load(path: String) async -> AppIndexIconResult {
        await withCheckedContinuation { continuation in
            queue.addOperation {
                let image = autoreleasepool { () -> CGImage? in
                    let icon = NSWorkspace.shared.icon(forFile: path)
                    var proposedRect = NSRect(x: 0, y: 0, width: 36, height: 36)
                    return icon.cgImage(
                        forProposedRect: &proposedRect,
                        context: nil,
                        hints: nil
                    )
                }
                continuation.resume(returning: AppIndexIconResult(image: image))
            }
        }
    }
}
