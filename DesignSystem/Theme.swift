import SwiftUI

// MARK: - Design Tokens (matches fotstat design file)

struct FSTheme {
    let mode: ColorScheme

    // Backgrounds
    var bg:      Color { mode == .dark ? Color(hex: "0A0A0B") : Color(hex: "F5F5F7") }
    var bgElev:  Color { mode == .dark ? Color(hex: "131316") : Color(hex: "FFFFFF") }
    var bgElev2: Color { mode == .dark ? Color(hex: "1B1B1F") : Color(hex: "FFFFFF") }
    var bgElev3: Color { mode == .dark ? Color(hex: "26262B") : Color(hex: "F0F0F2") }

    // Borders
    var line:      Color { mode == .dark ? Color.white.opacity(0.08) : Color.black.opacity(0.07) }
    var lineStrong:Color { mode == .dark ? Color.white.opacity(0.14) : Color.black.opacity(0.13) }

    // Text
    var text:    Color { mode == .dark ? Color.white : Color(hex: "0A0A0B") }
    var textSec: Color { mode == .dark ? Color.white.opacity(0.62) : Color.black.opacity(0.58) }
    var textTer: Color { mode == .dark ? Color.white.opacity(0.38) : Color.black.opacity(0.36) }

    // Semantic
    var pos:    Color { mode == .dark ? Color(hex: "23C779") : Color(hex: "0EA85C") } // win
    var neg:    Color { mode == .dark ? Color(hex: "FF4D4D") : Color(hex: "E0252F") } // loss
    var neu:    Color { mode == .dark ? Color.white.opacity(0.40) : Color.black.opacity(0.42) } // draw
    var yellow: Color { mode == .dark ? Color(hex: "F5C518") : Color(hex: "D9A300") }
    var fieldGrass: Color { mode == .dark ? Color(hex: "0E2A14") : Color(hex: "E8F1E2") }
    var fieldLine:  Color { mode == .dark ? Color.white.opacity(0.18) : Color.black.opacity(0.20) }

    // Accent (orange)
    let accent:     Color = Color(hex: "FF5C2B")
    let accentDeep: Color = Color(hex: "D9410F")
    let accentSoft: Color = Color(hex: "FF5C2B").opacity(0.15)

    // Glass tab bar
    var glassBg:     Color { mode == .dark ? Color(hex: "1C1C20").opacity(0.55) : Color.white.opacity(0.55) }
    var glassBorder: Color { mode == .dark ? Color.white.opacity(0.16) : Color.white.opacity(0.70) }
    var glassShadowColor: Color { mode == .dark ? Color.black.opacity(0.55) : Color.black.opacity(0.18) }
}

// MARK: - Environment Key

struct FSThemeKey: EnvironmentKey {
    static let defaultValue = FSTheme(mode: .dark)
}

struct FSSelectTeamKey: EnvironmentKey {
    static let defaultValue: (() -> Void)? = nil
}

extension EnvironmentValues {
    var fsTheme: FSTheme {
        get { self[FSThemeKey.self] }
        set { self[FSThemeKey.self] = newValue }
    }
    var fsSelectTeam: (() -> Void)? {
        get { self[FSSelectTeamKey.self] }
        set { self[FSSelectTeamKey.self] = newValue }
    }
}

// MARK: - Color Hex Init

extension Color {
    init(hex: String) {
        let hex = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: hex).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255
        let g = Double((int >> 8) & 0xFF) / 255
        let b = Double(int & 0xFF) / 255
        self.init(red: r, green: g, blue: b)
    }
}

// MARK: - Position Colors

func fsPosColor(_ pos: String) -> Color {
    switch pos {
    case "GK":          return Color(hex: "F5C518")
    case "CB","LB","RB":return Color(hex: "3FA9F5")
    case "CDM","CM","CAM": return Color(hex: "A07BFF")
    case "LW","RW","ST":return Color(hex: "FF5C2B")
    default:            return Color.gray
    }
}

// MARK: - Team Crest Color (hash-based)

func fsColorForName(_ name: String) -> Color {
    let palette: [String] = [
        "1B5E20","0D47A1","4A148C","B71C1C","37474F","3E2723","01579B","5D4037","1A237E"
    ]
    var h = 0
    for c in name.unicodeScalars { h = (h &* 31) &+ Int(c.value) }
    return Color(hex: palette[abs(h) % palette.count])
}

func fsInitials(_ name: String) -> String {
    let cleaned = name.replacingOccurrences(of: " ", with: "")
    return String(cleaned.prefix(2)).uppercased()
}
