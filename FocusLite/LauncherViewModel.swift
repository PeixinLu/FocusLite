import AppKit
import Foundation

@MainActor
final class LauncherViewModel: ObservableObject {
    @Published var searchText: String = ""
    @Published var searchState: SearchState = .initial()
    @Published var results: [ResultItem] = []
    @Published var focusToken = UUID()
    @Published var selectedIndex: Int?
    @Published var toastMessage: String?

    private let searchEngine: SearchEngine
    private var searchTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?

    var onExit: (() -> Void)?
    var onOpenSettings: ((SettingsTab) -> Void)?
    var onPrepareSettings: ((SettingsTab) -> Void)?
    var onPaste: ((String) -> Bool)?

    init(searchEngine: SearchEngine) {
        self.searchEngine = searchEngine
    }

    func handleExit() {
        onExit?()
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
    }

    func updateInput(_ text: String) {
        guard !isUpdatingText else { return }
        isUpdatingText = true
        let update = SearchStateReducer.handleInputChange(state: searchState, newText: text)
        searchState = update.state
        searchText = update.textFieldValue
        isUpdatingText = false
        performSearch()
    }

    func handleBackspaceKey() -> Bool {
        let update = SearchStateReducer.handleBackspace(state: searchState)
        let handled = update.state.scope != searchState.scope
        applyUpdate(update)
        if handled {
            performSearch()
        }
        return handled
    }

    func handleEscapeKey() {
        let update = SearchStateReducer.handleEscape(state: searchState, currentText: searchText)
        if update.state.scope != searchState.scope {
            applyUpdate(update)
            performSearch()
            return
        }
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

        switch item.action {
        case .copyText(let text):
            copyToPasteboard(text)
            showToast("已复制")
        case .openURL(let url):
            // 先退出避免焦点切换冲突
            onExit?()
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
            onExit?()
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
            break
        }

        onExit?()
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

    func activateClipboardSearch() {
        activatePrefix(providerID: ClipboardProvider.providerID)
    }

    func moveSelection(delta: Int) {
        guard !results.isEmpty else {
            selectedIndex = nil
            return
        }

        let current = selectedIndex ?? 0
        let next = max(0, min(current + delta, results.count - 1))
        selectedIndex = next
    }

    func selectIndex(_ index: Int) {
        guard results.indices.contains(index) else { return }
        selectedIndex = index
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
            let trimmed = searchText.trimmingCharacters(in: .whitespacesAndNewlines)
            if trimmed.isEmpty {
                let prefixItems = PrefixResultItemBuilder.items(matching: searchText)
                setResults(prefixItems)
                return
            }

            var prefixItems = PrefixResultItemBuilder.items(matching: trimmed)
            if !trimmed.isEmpty {
                let normalized = trimmed.lowercased()
                let hasExactMatch = prefixItems.contains { $0.title.lowercased() == normalized }
                if hasExactMatch {
                    prefixItems = prefixItems.filter { $0.title.lowercased().hasPrefix(normalized) }
                }
            }
            let currentState = searchState
            searchTask = Task.detached { [searchEngine] in
                let items = await searchEngine.search(
                    query: trimmed,
                    isScoped: false,
                    providerIDs: [AppSearchProvider.providerID]
                )
                if Task.isCancelled {
                    return
                }
                await MainActor.run { [weak self] in
                    guard self?.searchState == currentState else { return }
                    if items.isEmpty {
                        self?.setResults(prefixItems)
                    } else {
                        let hasExactPrefixMatch = prefixItems.contains { item in
                            item.title.lowercased() == trimmed.lowercased()
                        }
                        if hasExactPrefixMatch {
                            self?.setResults(prefixItems + items)
                        } else {
                            self?.setResults(items + prefixItems)
                        }
                    }
                }
            }
        case .prefixed(let providerID):
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
}
