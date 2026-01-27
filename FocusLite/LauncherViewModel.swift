import AppKit
import Foundation

@MainActor
final class LauncherViewModel: ObservableObject {
    enum ExitBehavior {
        case restoreOrigin
        case none
    }

    @Published var searchText: String = ""
    @Published var searchState: SearchState = .initial()
    @Published var results: [ResultItem] = []
    @Published var focusToken = UUID()
    @Published var selectedIndex: Int?
    @Published var shouldAnimateSelection = false
    @Published var toastMessage: String?

    private let searchEngine: SearchEngine
    private var searchTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?
    private var translationObserver: NSObjectProtocol?

    var onExit: ((ExitBehavior) -> Void)?
    var onOpenSettings: ((SettingsTab) -> Void)?
    var onPrepareSettings: ((SettingsTab) -> Void)?
    var onPaste: ((String) -> Bool)?
    var onPresentOnboarding: (() -> Void)?

    init(searchEngine: SearchEngine) {
        self.searchEngine = searchEngine
        translationObserver = NotificationCenter.default.addObserver(
            forName: .translationResultsUpdated,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            self?.handleTranslationUpdate(notification)
        }
    }

    deinit {
        if let translationObserver {
            NotificationCenter.default.removeObserver(translationObserver)
        }
    }

    func handleExit() {
        onExit?(.restoreOrigin)
    }

    func requestFocus() {
        focusToken = UUID()
    }

    func resetSearch() {
        searchTask?.cancel()
        searchState = .initial()
        searchText = ""
        results = []
        selectedIndex = nil
        shouldAnimateSelection = false
    }

    func updateInput(_ text: String) {
        guard !isUpdatingText else { return }
        isUpdatingText = true
        let update = SearchStateReducer.handleInputChange(state: searchState, newText: text)
        searchState = update.state
        searchText = update.textFieldValue
        isUpdatingText = false
        performSearch()
        shouldAnimateSelection = false
    }

    func handleBackspaceKey() -> Bool {
        let update = SearchStateReducer.handleBackspace(state: searchState)
        let handled = update.state.scope != searchState.scope
        applyUpdate(update)
        if handled {
            performSearch()
        }
        shouldAnimateSelection = false
        return handled
    }

    func handleEscapeKey() {
        let update = SearchStateReducer.handleEscape(state: searchState, currentText: searchText)
        if update.state.scope != searchState.scope {
            applyUpdate(update)
            performSearch()
            shouldAnimateSelection = false
            return
        }
        shouldAnimateSelection = false
        handleExit()
    }

    func submitPrimaryAction() {
        guard let item = selectedItem() else { return }

        if item.isPrefix {
            let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                activatePrefix(providerID: item.providerID)
                return
            }

            let lowered = trimmed.lowercased()
            let prefixText = item.title.lowercased()
            if prefixText.hasPrefix(lowered) {
                activatePrefix(providerID: item.providerID)
            } else {
                activatePrefix(providerID: item.providerID, carryQuery: trimmed)
            }
            return
        }

        if item.providerID == StyleProvider.providerID {
            // 调试模式不触发复制或退出
            shouldAnimateSelection = false
            return
        }

        switch item.action {
        case .copyText(let text):
            copyToPasteboard(text)
            showToast("已复制")
        case .openURL(let url):
            // 先退出避免焦点切换冲突
            onExit?(.none)
            // 延迟打开以确保窗口先隐藏
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                NSWorkspace.shared.open(url)
            }
            return
        case .pasteText(let text):
            copyToPasteboard(text)
            if onPaste?(text) == true {
                return
            }
            showToast("已复制，开启辅助功能权限可自动粘贴")
        case .runApp(let bundleID):
            // 先退出避免焦点切换冲突
            onExit?(.none)
            // 延迟启动以确保窗口先隐藏
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                NSWorkspace.shared.launchApplication(
                    withBundleIdentifier: bundleID,
                    options: [.default],
                    additionalEventParamDescriptor: nil,
                    launchIdentifier: nil
                )
            }
            return
        case .copyImage(let data, let type):
            copyImageToPasteboard(data, type: type)
            showToast("已复制图片")
        case .copyFiles(let paths):
            copyFilesToPasteboard(paths)
            showToast("已复制文件")
        case .none:
            if item.providerID == WebSearchProvider.providerID {
                showToast("请输入内容后再搜索")
                shouldAnimateSelection = false
                return
            }
            break
        }

        onExit?(.restoreOrigin)
        shouldAnimateSelection = false
    }

    func openSnippetsManager() {
        onOpenSettings?(.snippets)
    }

    func prepareSettings(tab: SettingsTab) {
        onPrepareSettings?(tab)
    }

    func openSettings(tab: SettingsTab = .general) {
        onOpenSettings?(tab)
    }

    func preferredSettingsTab() -> SettingsTab {
        switch searchState.scope {
        case .global:
            return .apps
        case .prefixed(let providerID):
            switch providerID {
            case TranslateProvider.providerID:
                return .translate
            case ClipboardProvider.providerID:
                return .clipboard
            case SnippetsProvider.providerID:
                return .snippets
            case StyleProvider.providerID:
                return .general
            default:
                return .apps
            }
        }
    }

    func activateClipboardSearch() {
        activatePrefix(providerID: ClipboardProvider.providerID)
    }

    func activateCustomPrefix(_ entry: PrefixEntry, carryQuery: String? = nil) {
        let update: SearchStateReducer.UpdateResult
        if let carryQuery, !carryQuery.isEmpty {
            update = SearchStateReducer.selectPrefix(state: searchState, prefix: entry, carryQuery: carryQuery)
        } else {
            update = SearchStateReducer.selectPrefix(state: searchState, prefix: entry)
        }
        applyUpdate(update)
        focusToken = UUID()
        performSearch()
    }

    func moveSelection(delta: Int) {
        guard !results.isEmpty else {
            selectedIndex = nil
            return
        }

        let current = selectedIndex ?? 0
        let next = max(0, min(current + delta, results.count - 1))
        selectedIndex = next
        shouldAnimateSelection = true
    }

    func selectIndex(_ index: Int) {
        guard results.indices.contains(index) else { return }
        selectedIndex = index
        shouldAnimateSelection = false
    }

    var highlightedItem: ResultItem? {
        if let index = selectedIndex, results.indices.contains(index) {
            return results[index]
        }
        return results.first
    }

    private func setResults(_ items: [ResultItem]) {
        results = items
        selectedIndex = items.isEmpty ? nil : 0
    }

    private func selectedItem() -> ResultItem? {
        if let index = selectedIndex, results.indices.contains(index) {
            return results[index]
        }
        return results.first
    }

    private func copyToPasteboard(_ text: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.setString(text, forType: .string)
    }

    private func showToast(_ message: String) {
        toastTask?.cancel()
        toastMessage = message

        toastTask = Task { @MainActor in
            try? await Task.sleep(nanoseconds: 900_000_000)
            toastMessage = nil
        }
    }

    private func copyImageToPasteboard(_ data: Data, type: String) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        let pbType = NSPasteboard.PasteboardType(type)
        if !pasteboard.setData(data, forType: pbType) {
            if let image = NSImage(data: data) {
                pasteboard.writeObjects([image])
            } else {
                pasteboard.setData(data, forType: .tiff)
            }
        }
    }

    private func copyFilesToPasteboard(_ paths: [String]) {
        let urls = paths.compactMap { URL(fileURLWithPath: $0) as NSURL }
        guard !urls.isEmpty else { return }
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()
        pasteboard.writeObjects(urls)
    }


    private func performSearch() {
        searchTask?.cancel()

        switch searchState.scope {
        case .global:
            let rawText = searchText
            let trimmed = rawText.trimmingCharacters(in: .whitespacesAndNewlines)
            let isDirectoryMode = trimmed.hasPrefix("/")
            if trimmed.isEmpty && !isDirectoryMode {
                let prefixItems = PrefixResultItemBuilder.items(matching: searchText)
                setResults(prefixItems)
                return
            }

            var prefixItems: [ResultItem] = []
            var hasExactPrefixMatch = false
            if !isDirectoryMode {
                prefixItems = PrefixResultItemBuilder.items(matching: trimmed)
                if !trimmed.isEmpty {
                    let normalized = trimmed.lowercased()
                    let exactMatch = prefixItems.contains { $0.title.lowercased() == normalized }
                    hasExactPrefixMatch = exactMatch
                    if exactMatch {
                        prefixItems = prefixItems.filter { $0.title.lowercased().hasPrefix(normalized) }
                    }
                }
            }
            let currentState = searchState
            searchTask = Task.detached { [searchEngine] in
                async let appItemsTask: [ResultItem] = isDirectoryMode ? [] : searchEngine.search(
                    query: trimmed,
                    isScoped: false,
                    providerIDs: [AppSearchProvider.providerID, CalcProvider.providerID]
                )
                async let directoryItemsTask: [ResultItem] = searchEngine.search(
                    query: trimmed,
                    isScoped: false,
                    providerIDs: [QuickDirectoryProvider.providerID]
                )
                async let webItemsTask: [ResultItem] = isDirectoryMode ? [] : searchEngine.search(
                    query: trimmed,
                    isScoped: false,
                    providerIDs: [WebSearchProvider.providerID]
                )
                let items = await appItemsTask
                let directoryItems = await directoryItemsTask
                let webItems = await webItemsTask
                if Task.isCancelled {
                    return
                }
                await MainActor.run { [weak self] in
                    guard self?.searchState == currentState else { return }
                    guard let self else { return }
                    if isDirectoryMode {
                        self.setResults(directoryItems)
                        return
                    }

                    var combined: [ResultItem] = []
                    if hasExactPrefixMatch {
                        combined.append(contentsOf: prefixItems)
                        combined.append(contentsOf: items)
                    } else {
                        combined.append(contentsOf: items)
                        combined.append(contentsOf: prefixItems)
                    }
                    combined.append(contentsOf: directoryItems)
                    if let boosted = webItems.first, boosted.score > 1.0 {
                        combined.insert(boosted, at: 0)
                    } else {
                        combined.append(contentsOf: webItems)
                    }
                    self.setResults(combined)
                }
            }
        case .prefixed(let providerID):
            if providerID == TranslateProvider.providerID {
                let trimmed = searchState.query.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    setResults(translateItems(from: []))
                }
            }
            let currentState = searchState
            searchTask = Task.detached { [searchEngine] in
                let items = await searchEngine.search(
                    query: currentState.query,
                    isScoped: true,
                    providerIDs: [providerID]
                )
                if Task.isCancelled {
                    return
                }
                await MainActor.run { [weak self] in
                    guard self?.searchState == currentState else { return }
                    self?.setResults(items)
                }
            }
        }
    }

    private func applyUpdate(_ update: SearchStateReducer.UpdateResult) {
        isUpdatingText = true
        searchState = update.state
        searchText = update.textFieldValue
        isUpdatingText = false
    }

    private func activatePrefix(providerID: String, carryQuery: String? = nil) {
        guard let entry = PrefixRegistry.entries().first(where: { $0.providerID == providerID }) else { return }
        let update: SearchStateReducer.UpdateResult
        if let carryQuery, !carryQuery.isEmpty {
            update = SearchStateReducer.selectPrefix(state: searchState, prefix: entry, carryQuery: carryQuery)
        } else {
            update = SearchStateReducer.selectPrefix(state: searchState, prefix: entry)
        }
        applyUpdate(update)
        focusToken = UUID()
        performSearch()
    }

    private var isUpdatingText = false

    private func translateItems(from results: [TranslationResult]) -> [ResultItem] {
        let projects = TranslatePreferences.activeProjects()
        guard !projects.isEmpty else {
            return [ResultItem(
                title: "正在翻译…",
                subtitle: "未配置翻译服务",
                icon: .system("arrow.triangle.2.circlepath"),
                score: 0.1,
                action: .none,
                providerID: TranslateProvider.providerID,
                category: .standard
            )]
        }

        let resultMap = Dictionary(uniqueKeysWithValues: results.map { ($0.projectID, $0) })
        return projects.enumerated().map { index, project in
            if let result = resultMap[project.id] {
                let action: ResultAction = TranslatePreferences.autoPasteAfterSelect
                    ? .pasteText(result.translatedText)
                    : .copyText(result.translatedText)
                let fallbackNote = result.usedFallback ? " · 自动识别失败，按默认方向" : ""
                return ResultItem(
                    title: result.translatedText,
                    subtitle: "\(result.serviceName) · \(TranslatePreferences.displayName(for: result.sourceLanguage)) → \(TranslatePreferences.displayName(for: result.targetLanguage))\(fallbackNote)",
                    icon: .system("globe"),
                    score: 0.9 - Double(index) * 0.05,
                    action: action,
                    providerID: TranslateProvider.providerID,
                    category: .standard
                )
            }
            let serviceName = serviceDisplayName(for: TranslateServiceID(rawValue: project.serviceID))
            return ResultItem(
                title: "正在翻译…",
                subtitle: "\(serviceName) · \(TranslatePreferences.displayName(for: project.primaryLanguage)) ↔ \(TranslatePreferences.displayName(for: project.secondaryLanguage))",
                icon: .system("arrow.triangle.2.circlepath"),
                score: 0.2 - Double(index) * 0.01,
                action: .none,
                providerID: TranslateProvider.providerID,
                category: .standard
            )
        }
    }

    private func handleTranslationUpdate(_ notification: Notification) {
        guard case .prefixed(let providerID) = searchState.scope,
              providerID == TranslateProvider.providerID else {
            return
        }
        let currentQuery = searchState.query.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let info = notification.userInfo,
              let query = info[TranslationCoordinator.queryKey] as? String,
              let results = info[TranslationCoordinator.resultsKey] as? [TranslationResult] else {
            return
        }
        guard !query.isEmpty, query == currentQuery else { return }
        setResults(translateItems(from: results))
    }

    private func serviceDisplayName(for id: TranslateServiceID?) -> String {
        guard let id else { return "未知服务" }
        switch id {
        case .youdaoAPI:
            return "有道 API"
        case .baiduAPI:
            return "百度 API"
        case .googleAPI:
            return "Google API"
        case .bingAPI:
            return "微软翻译 API"
        case .deepseekAPI:
            return "DeepSeek API"
        }
    }
}
