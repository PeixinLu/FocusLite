import Foundation

struct SearchState: Equatable {
    var query: String
    var scope: SearchScope
    var activePrefix: ActivePrefix?

    static func initial() -> SearchState {
        SearchState(query: "", scope: .global, activePrefix: nil)
    }
}

enum SearchScope: Equatable {
    case global
    case prefixed(providerID: String)
}

struct ActivePrefix: Equatable {
    let id: String
    let providerID: String
    let title: String
    let subtitle: String?
}
