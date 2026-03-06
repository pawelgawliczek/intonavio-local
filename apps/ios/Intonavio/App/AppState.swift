import SwiftUI

/// Global app state shared across the entire view hierarchy.
@Observable
final class AppState {
    var selectedTab: Tab = .library

    enum Tab: Int {
        case library = 0
        case sessions = 1
        case settings = 2
    }
}
