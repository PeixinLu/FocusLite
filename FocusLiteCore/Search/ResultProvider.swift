import Foundation

protocol ResultProvider: Sendable {
    var id: String { get }
    var displayName: String { get }
    func results(for query: String) async -> [ResultItem]
}
