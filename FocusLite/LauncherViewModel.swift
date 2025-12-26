import AppKit
import Foundation

@MainActor
final class LauncherViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var results: [ResultItem] = []
    @Published var focusToken = UUID()
    @Published var selectedIndex: Int?
    @Published var toastMessage: String?

    private let searchEngine: SearchEngine
    private var searchTask: Task<Void, Never>?
    private var toastTask: Task<Void, Never>?

    var onExit: (() -> Void)?

    init(searchEngine: SearchEngine) {
        self.searchEngine = searchEngine
    }

    func search(query: String) {
        searchTask?.cancel()

        let trimmed = query.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            results = []
            return
        }

        searchTask = Task.detached { [searchEngine, trimmed] in
            let items = await searchEngine.search(query: trimmed)
            if Task.isCancelled {
                return
            }
            await MainActor.run { [weak self] in
                self?.setResults(items)
            }
        }
    }

    func handleExit() {
        onExit?()
    }

    func requestFocus() {
        focusToken = UUID()
    }

    func submitPrimaryAction() {
        guard let item = selectedItem() else { return }

        switch item.action {
        case .copyText(let text):
            copyToPasteboard(text)
            showToast("已复制")
        case .openURL(let url):
            NSWorkspace.shared.open(url)
        case .runApp(let bundleID):
            NSWorkspace.shared.launchApplication(
                withBundleIdentifier: bundleID,
                options: [.default],
                additionalEventParamDescriptor: nil,
                launchIdentifier: nil
            )
        case .none:
            break
        }

        onExit?()
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
}
