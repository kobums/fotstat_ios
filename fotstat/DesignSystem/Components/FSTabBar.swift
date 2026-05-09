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

struct FSTabBar: View {
    @Binding var selected: FSTab
    @Environment(\.fsTheme) var t
    @Environment(\.colorScheme) var scheme

    var body: some View {
        HStack(spacing: 0) {
            ForEach(FSTab.allCases, id: \.self) { tab in
                Button {
                    selected = tab
                } label: {
                    VStack(spacing: 2) {
                        Image(systemName: tab.icon)
                            .font(.system(size: 20, weight: .medium))
                        Text(tab.label)
                            .font(.system(size: 10, weight: .bold))
                    }
                    .foregroundColor(selected == tab ? t.text : t.textTer)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        Group {
                            if selected == tab {
                                RoundedRectangle(cornerRadius: 14)
                                    .fill(t.mode == .dark ? Color.white.opacity(0.10) : Color.black.opacity(0.06))
                                    .frame(width: 52, height: 44)
                            }
                        }
                    )
                }
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(
            ZStack {
                BlurView(style: scheme == .dark ? .systemUltraThinMaterialDark : .systemUltraThinMaterialLight)
                t.glassBg
            }
            .clipShape(Capsule())
            .overlay(
                Capsule()
                    .stroke(t.glassBorder, lineWidth: 0.5)
            )
            .shadow(color: t.glassShadowColor, radius: 14, x: 0, y: 6)
        )
        .clipShape(Capsule())
        .padding(.horizontal, 16)
    }
}
