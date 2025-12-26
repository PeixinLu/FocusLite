import Foundation

@MainActor
final class LauncherViewModel: ObservableObject {
    @Published var query: String = ""
    @Published var results: [ResultItem] = []
    @Published var focusToken = UUID()

    private let searchEngine: SearchEngine
    private var searchTask: Task<Void, Never>?

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
                self?.results = items
            }
        }
    }

    func handleExit() {
        onExit?()
    }

    func requestFocus() {
        focusToken = UUID()
    }
}
