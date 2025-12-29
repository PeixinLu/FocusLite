import CoreServices
import Foundation

actor AppIndex {
    static let shared = AppIndex()

    struct AppEntry: Codable, Hashable, Sendable, Identifiable {
        let name: String
        let path: String
        let bundleID: String?
        let nameIndex: AppNameIndex

        var id: String { bundleID ?? path }
    }

    private var apps: [AppEntry] = []
    private var refreshTask: Task<Void, Never>?
    private var didScheduleRefresh = false
    private let cacheURL: URL
    private let aliasURL: URL
    private let searchRoots: [URL]

    init(fileManager: FileManager = .default) {
        let focusLiteDir = AppIndex.defaultSupportDirectory(fileManager: fileManager)
        cacheURL = focusLiteDir.appendingPathComponent("app_index.json")
        aliasURL = focusLiteDir.appendingPathComponent("aliases.json")
        searchRoots = [
            URL(fileURLWithPath: "/Applications", isDirectory: true),
            URL(fileURLWithPath: "/Applications/Utilities", isDirectory: true),
            fileManager.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)
        ]
    }

    func warmUp() {
        guard !didScheduleRefresh else { return }
        didScheduleRefresh = true

        refreshTask = Task.detached(priority: .utility) { [cacheURL, aliasURL, searchRoots] in
            let cachedApps = AppIndex.loadCache(from: cacheURL)
            await self.applyCacheIfEmpty(cachedApps)

            let userAliasStore = UserAliasStore(fileURL: aliasURL)
            let userPayload = userAliasStore.snapshot()
            let userAliases = AliasStore(
                userAliases: userPayload.byName ?? userPayload.aliases ?? [:],
                bundleAliases: userPayload.byBundleID
            )
            let aliasStore = AliasStore.builtIn.merged(with: userAliases)
            let pinyinProvider = PinyinProviderFactory.make()

            let spotlightApps = AppIndex.collectApplications(
                from: AppIndex.spotlightApplicationURLs(),
                aliasStore: aliasStore,
                pinyinProvider: pinyinProvider
            )
            let scannedApps = AppIndex.scanApplications(
                at: searchRoots,
                aliasStore: aliasStore,
                pinyinProvider: pinyinProvider
            )
            let mergedApps = AppIndex.merge([spotlightApps, scannedApps])
            await self.replaceApps(mergedApps)
            AppIndex.saveCache(mergedApps, to: cacheURL)

            await self.finishRefresh()
        }
    }

    func snapshot() -> [AppEntry] {
        apps
    }

    func rebuild() async {
        let userAliasStore = UserAliasStore(fileURL: aliasURL)
        let userPayload = userAliasStore.snapshot()
        let userAliases = AliasStore(
            userAliases: userPayload.byName ?? userPayload.aliases ?? [:],
            bundleAliases: userPayload.byBundleID
        )
        let aliasStore = AliasStore.builtIn.merged(with: userAliases)
        let pinyinProvider = PinyinProviderFactory.make()

        let spotlightApps = AppIndex.collectApplications(
            from: AppIndex.spotlightApplicationURLs(),
            aliasStore: aliasStore,
            pinyinProvider: pinyinProvider
        )
        let scannedApps = AppIndex.scanApplications(
            at: searchRoots,
            aliasStore: aliasStore,
            pinyinProvider: pinyinProvider
        )
        let mergedApps = AppIndex.merge([spotlightApps, scannedApps])
        apps = mergedApps
        AppIndex.saveCache(mergedApps, to: cacheURL)
    }

    func refreshAliases() async {
        let userAliasStore = UserAliasStore(fileURL: aliasURL)
        let userPayload = userAliasStore.snapshot()
        let userAliases = AliasStore(
            userAliases: userPayload.byName ?? userPayload.aliases ?? [:],
            bundleAliases: userPayload.byBundleID
        )
        let aliasStore = AliasStore.builtIn.merged(with: userAliases)
        let pinyinProvider = PinyinProviderFactory.make()

        apps = apps.map { entry in
            AppEntry(
                name: entry.name,
                path: entry.path,
                bundleID: entry.bundleID,
                nameIndex: AppNameIndex(
                    name: entry.name,
                    aliasEntry: aliasStore.entry(for: entry.name, bundleID: entry.bundleID),
                    pinyinProvider: pinyinProvider
                )
            )
        }
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

    static func aliasFileURL(fileManager: FileManager = .default) -> URL {
        defaultSupportDirectory(fileManager: fileManager).appendingPathComponent("aliases.json")
    }

    private static func defaultSupportDirectory(fileManager: FileManager) -> URL {
        let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
        let baseURL = appSupport ?? URL(fileURLWithPath: NSTemporaryDirectory(), isDirectory: true)
        return baseURL.appendingPathComponent("FocusLite", isDirectory: true)
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

    private static func collectApplications(
        from urls: [URL],
        aliasStore: AliasStore,
        pinyinProvider: PinyinProvider
    ) -> [AppEntry] {
        var collected: [AppEntry] = []
        collected.reserveCapacity(urls.count)
        let fileManager = FileManager.default
        for url in urls {
            guard url.pathExtension == "app" else { continue }
            guard fileManager.fileExists(atPath: url.path) else { continue }
            if let entry = AppEntry.make(from: url, aliasStore: aliasStore, pinyinProvider: pinyinProvider) {
                collected.append(entry)
            }
        }
        return dedupe(collected).sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private static func merge(_ lists: [[AppEntry]]) -> [AppEntry] {
        let combined = lists.flatMap { $0 }
        return dedupe(combined).sorted {
            $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    private static func spotlightApplicationURLs() -> [URL] {
        let queryString = "kMDItemContentType == 'com.apple.application-bundle'"
        guard let query = MDQueryCreate(kCFAllocatorDefault, queryString as CFString, nil, nil) else {
            return []
        }
        let executed = MDQueryExecute(query, CFOptionFlags(kMDQuerySynchronous.rawValue))
        guard executed else { return [] }

        let count = MDQueryGetResultCount(query)
        guard count > 0 else { return [] }

        var urls: [URL] = []
        urls.reserveCapacity(count)
        for index in 0..<count {
            guard let rawItem = MDQueryGetResultAtIndex(query, index) else { continue }
            let item = unsafeBitCast(rawItem, to: MDItem.self)
            if let path = MDItemCopyAttribute(item, kMDItemPath as CFString) as? String {
                urls.append(URL(fileURLWithPath: path))
            }
        }
        return urls
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

extension AppIndex.AppEntry {
    static func make(from url: URL, aliasStore: AliasStore, pinyinProvider: PinyinProvider) -> AppIndex.AppEntry? {
        let bundle = Bundle(url: url)
        if let bundle, shouldExclude(bundle: bundle, url: url) {
            return nil
        }
        let name = resolveName(from: url, bundle: bundle)
        guard !name.isEmpty else { return nil }

        let bundleID = bundle?.bundleIdentifier
        
        // 获取文件名（英文原名）
        let fileName = url.deletingPathExtension().lastPathComponent
        
        // 合并用户配置的别名和文件名
        var aliasEntry = aliasStore.entry(for: name, bundleID: bundleID)
        
        // 如果显示名和文件名不同，将文件名作为别名加入
        if fileName != name && !fileName.isEmpty {
            let fileNameTokens = MatchingNormalizer.tokens(from: fileName)
            if let existing = aliasEntry {
                // 合并现有别名和文件名 token
                aliasEntry = AliasEntry(
                    full: existing.full,
                    initials: existing.initials,
                    extra: Array(Set(existing.extra + fileNameTokens))
                )
            } else {
                // 创建新的别名，包含文件名 token
                aliasEntry = AliasEntry(full: [], initials: [], extra: fileNameTokens)
            }
        }
        
        let nameIndex = AppNameIndex(name: name, aliasEntry: aliasEntry, pinyinProvider: pinyinProvider)

        return AppIndex.AppEntry(
            name: name,
            path: url.path,
            bundleID: bundleID,
            nameIndex: nameIndex
        )
    }

    static func resolveName(from url: URL, bundle: Bundle?) -> String {
        let fallback = url.deletingPathExtension().lastPathComponent
        let candidates = localizedNameCandidates(from: url, bundle: bundle, fallback: fallback)
        if let preferred = candidates.first(where: { containsCJK($0) }) {
            return preferred
        }
        return candidates.first(where: { !$0.isEmpty }) ?? fallback
    }

    static func shouldExclude(bundle: Bundle, url: URL) -> Bool {
        if let packageType = bundle.object(forInfoDictionaryKey: "CFBundlePackageType") as? String,
           packageType != "APPL" {
            return true
        }

        let info = bundle.infoDictionary ?? [:]
        if let uiElement = info["LSUIElement"] as? Bool, uiElement {
            return true
        }
        if let uiElement = info["LSUIElement"] as? String, uiElement == "1" {
            return true
        }
        if let background = info["LSBackgroundOnly"] as? Bool, background {
            return true
        }
        if let background = info["LSBackgroundOnly"] as? String, background == "1" {
            return true
        }

        if url.path.contains("/Contents/Library/") {
            return true
        }
        if url.path.contains("/Library/Input Methods/") || url.path.contains("/System/Library/Input Methods/") {
            return true
        }
        if url.path.contains("/Library/Keyboard Layouts/") || url.path.contains("/System/Library/Keyboard Layouts/") {
            return true
        }
        if url.path.contains("/Library/Components/") || url.path.contains("/System/Library/Components/") {
            return true
        }
        if url.path.contains("/Applications/Xcode.app/Contents/Applications/") {
            return true
        }
        if url.path.contains("/Applications/Xcode.app/Contents/Developer/Applications/") {
            return true
        }

        return false
    }

    static func displayNameFromLaunchServices(_ url: URL) -> String? {
        let cfURL = url as CFURL
        var name: Unmanaged<CFString>?
        let status = LSCopyDisplayNameForURL(cfURL, &name)
        guard status == noErr, let managed = name else {
            return nil
        }
        let value = managed.takeRetainedValue() as String
        return value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func displayNameFromSpotlight(_ url: URL) -> String? {
        // 使用 Spotlight 元数据获取本地化名称
        // 这对系统应用特别有效，因为它们的本地化名称存储在 Spotlight 索引中
        guard let mdItem = MDItemCreate(kCFAllocatorDefault, url.path as CFString) else {
            return nil
        }
        
        // kMDItemDisplayName 包含系统提供的本地化名称
        guard let displayName = MDItemCopyAttribute(mdItem, kMDItemDisplayName) as? String else {
            return nil
        }
        
        return displayName.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    static func displayNameWithLocale(_ url: URL, locale: String) -> String? {
        // 尝试从 Bundle 的特定语言本地化资源中获取名称
        guard let bundle = Bundle(url: url) else { return nil }
        
        if let path = bundle.path(forResource: "InfoPlist", ofType: "strings", inDirectory: nil, forLocalization: locale),
           let dict = NSDictionary(contentsOfFile: path) as? [String: Any] {
            if let display = dict["CFBundleDisplayName"] as? String, !display.isEmpty {
                return display.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            if let name = dict["CFBundleName"] as? String, !name.isEmpty {
                return name.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }
        return nil
    }

    private static func containsCJK(_ value: String) -> Bool {
        value.unicodeScalars.contains { MatchingNormalizer.isCJKUnifiedIdeograph($0) }
    }

    nonisolated static func chineseName(for path: String) -> String? {
        let url = URL(fileURLWithPath: path)
        let bundle = Bundle(url: url)
        let fallback = url.deletingPathExtension().lastPathComponent
        let candidates = localizedNameCandidates(from: url, bundle: bundle, fallback: fallback)
        return candidates.first(where: { containsCJK($0) })
    }

    private static func localizedNameCandidates(from url: URL, bundle: Bundle?, fallback: String) -> [String] {
        var candidates: [String] = []
        let chineseVariants = ["zh-Hans", "zh-Hant", "zh_CN", "zh_TW", "zh"]

        // 最高优先级：Spotlight 元数据（系统应用的本地化名称存储在这里）
        if let spotlightName = displayNameFromSpotlight(url) {
            candidates.append(spotlightName)
        }

        // 优先读取中文本地化资源（第三方应用通常使用这种方式）
        if let bundle {
            for localization in chineseVariants {
                if let path = bundle.path(forResource: "InfoPlist", ofType: "strings", inDirectory: nil, forLocalization: localization),
                   let dict = NSDictionary(contentsOfFile: path) as? [String: Any] {
                    if let display = dict["CFBundleDisplayName"] as? String {
                        candidates.append(display)
                    }
                    if let name = dict["CFBundleName"] as? String {
                        candidates.append(name)
                    }
                }
            }
        }

        // LaunchServices 在某些情况下能返回本地化名称
        if let lsDisplay = displayNameFromLaunchServices(url) {
            candidates.append(lsDisplay)
        }

        // FileManager displayName 可能包含本地化名称
        let fileDisplay = FileManager.default.displayName(atPath: url.path)
        candidates.append(fileDisplay)

        // 资源的 localizedName
        if let resource = try? url.resourceValues(forKeys: [.localizedNameKey]),
           let localizedName = resource.localizedName {
            candidates.append(localizedName)
        }

        // Bundle 的本地化信息（依赖系统语言设置）
        if let bundle {
            if let info = bundle.localizedInfoDictionary {
                if let display = info["CFBundleDisplayName"] as? String {
                    candidates.append(display)
                }
                if let name = info["CFBundleName"] as? String {
                    candidates.append(name)
                }
            }

            if let display = bundle.object(forInfoDictionaryKey: "CFBundleDisplayName") as? String {
                candidates.append(display)
            }
            if let name = bundle.object(forInfoDictionaryKey: "CFBundleName") as? String {
                candidates.append(name)
            }
        }

        candidates.append(fallback)

        return candidates
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
    }
}
