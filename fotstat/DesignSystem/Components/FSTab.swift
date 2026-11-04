import SwiftUI

enum FSTab: CaseIterable {
    case home, squad, matches, stats

    var label: String {
        switch self {
        case .home:    return "Home"
        case .squad:   return "Squad"
        case .matches: return "Matches"
        case .stats:   return "Stats"
        }
    }

    var icon: String {
        switch self {
        case .home:    return "house.fill"
        case .squad:   return "person.3.fill"
        case .matches: return "soccerball"
        case .stats:   return "chart.bar.fill"
        }
    }
}
