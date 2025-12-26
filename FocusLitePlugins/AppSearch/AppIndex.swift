import Foundation

actor AppIndex {
    static let shared = AppIndex()

    struct AppEntry: Codable, Hashable, Sendable {
        let name: String
        let path: String
        let bundleID: String?
        let nameIndex: AppNameIndex
    }

    private var apps: [AppEntry] = []
    private var refreshTask: Task<Void, Never>?
    private var didScheduleRefresh = false
    private let cacheURL: URL
    private let aliasURL: URL
    private let searchRoots: [URL]

    init(fileManager: FileManager = .default) {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let baseURL = appSupport ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        let focusLiteDir = baseURL.appendingPathComponent("FocusLite", isDirectory: true)
        cacheURL = focusLiteDir.appendingPathComponent("app_index.json")
        aliasURL = focusLiteDir.appendingPathComponent("aliases.json")
        searchRoots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]
    }

    func warmUp() {
        guard !didScheduleRefresh else { return }
        didScheduleRefresh = true

        refreshTask = Task.detached(priority: .utility) { [cacheURL, aliasURL, searchRoots] in
            let cachedApps = AppIndex.loadCache(from: cacheURL)
            await self.applyCacheIfEmpty(cachedApps)

            let userAliases = AliasStore.loadUserAliases(from: aliasURL)
            let aliasStore = AliasStore.builtIn.merged(with: userAliases)
            let pinyinProvider = SystemPinyinProvider()

            let scannedApps = AppIndex.scanApplications(
                at: searchRoots,
                aliasStore: aliasStore,
                pinyinProvider: pinyinProvider
            )
            await self.replaceApps(scannedApps)
            AppIndex.saveCache(scannedApps, to: cacheURL)

            await self.finishRefresh()
        }
    }

    func snapshot() -> [AppEntry] {
        apps
    }

    private func applyCacheIfEmpty(_ cached: [AppEntry]) {
        if apps.isEmpty {
            apps = cached
        }
    }

    private func replaceApps(_ newApps: [AppEntry]) {
        apps = newApps
    }

    private func finishRefresh() {
        refreshTask = nil
    }

    private static func loadCache(from url: URL) -> [AppEntry] {
        guard let data = try? Data(contentsOf: url) else {
            return []
        }
        return (try? JSONDecoder().decode([AppEntry].self, from: data)) ?? []
    }

    private static func saveCache(_ apps: [AppEntry], to url: URL) {
        let directory = url.deletingLastPathComponent()
        try? FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true, attributes: nil)
        guard let data = try? JSONEncoder().encode(apps) else {
            return
        }
        try? data.write(to: url, options: [.atomic])
    }

    private static func scanApplications(
        at roots: [URL],
        aliasStore: AliasStore,
        pinyinProvider: PinyinProvider
    ) -> [AppEntry] {
        let fileManager = FileManager.default
        var collected: [AppEntry] = []

        for root in roots {
            guard fileManager.fileExists(atPath: root.path) else { continue }
            guard let enumerator = fileManager.enumerator(
                at: root,
                includingPropertiesForKeys: [.isDirectoryKey, .isPackageKey, .localizedNameKey],
                options: [.skipsHiddenFiles, .skipsPackageDescendants]
            ) else {
                continue
            }

            for case let url as URL in enumerator {
                if url.pathExtension == "app" {
                    enumerator.skipDescendants()
                    if let entry = AppEntry.make(from: url, aliasStore: aliasStore, pinyinProvider: pinyinProvider) {
                        collected.append(entry)
                    }
                }
            }
        }

        return dedupe(collected).sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private static func dedupe(_ apps: [AppEntry]) -> [AppEntry] {
        var seen = Set<String>()
        var result: [AppEntry] = []
        result.reserveCapacity(apps.count)

        for app in apps {
            let key = app.bundleID ?? app.path
            if seen.insert(key).inserted {
                result.append(app)
            }
        }
        return result
    }
}

private extension AppIndex.AppEntry {
    static func make(from url: URL, aliasStore: AliasStore, pinyinProvider: PinyinProvider) -> AppIndex.AppEntry? {
        let bundle = Bundle(url: url)
        let name = resolveName(from: url, bundle: bundle)
        guard !name.isEmpty else { return nil }

        let bundleID = bundle?.bundleIdentifier
        let aliasEntry = aliasStore.entry(for: name)
        let nameIndex = AppNameIndex(name: name, aliasEntry: aliasEntry, pinyinProvider: pinyinProvider)

        return AppIndex.AppEntry(
            name: name,
            path: url.path,
            bundleID: bundleID,
            nameIndex: nameIndex
        )
    }

    static func resolveName(from url: URL, bundle: Bundle?) -> String {
        let localizedName = (try? url.resourceValues(forKeys: [.localizedNameKey]))?.localizedName
        let localizedDisplay = bundle?.localizedInfoDictionary?["CFBundleDisplayName"] as? String
        let localizedBundleName = bundle?.localizedInfoDictionary?["CFBundleName"] as? String
        let displayName = bundle?.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String
        let bundleName = bundle?.object(forInfoDictionaryKey: "CFBundleName") as? String

        let fallback = url.deletingPathExtension().lastPathComponent

        let candidates = [
            localizedName,
            localizedDisplay,
            localizedBundleName,
            displayName,
            bundleName,
            fallback
        ]

        return candidates
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .first(where: { !$0.isEmpty }) ?? fallback
    }
}
