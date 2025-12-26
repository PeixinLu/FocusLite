import XCTest
@testable import FocusLite

final class FocusLiteTests: XCTestCase {
    func testSearchEngineAggregatesAndSorts() async {
        let providerA = TestProvider(items: [
            ResultItem(title: "A", score: 0.2),
            ResultItem(title: "B", score: 0.5)
        ])
        let providerB = TestProvider(items: [
            ResultItem(title: "C", score: 0.9)
        ])

        let engine = SearchEngine(providers: [providerA, providerB])
        let results = await engine.search(query: "test")

        XCTAssertEqual(results.map(\.title), ["C", "B", "A"])
    }
}

private struct TestProvider: ResultProvider {
    let id = "test"
    let displayName = "Test"
    let items: [ResultItem]

    func results(for query: String) async -> [ResultItem] {
        items
    }
}
