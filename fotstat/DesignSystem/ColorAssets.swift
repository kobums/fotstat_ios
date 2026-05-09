// Assets.xcassets 대신 코드로 색상 정의
// Xcode Assets에서 아래 이름으로 Color Set을 만들거나
// 이 파일의 extension으로 직접 사용 가능

import SwiftUI

// MARK: - Programmatic Color Definitions (다크모드 대응)

extension Color {
    static func adaptive(light: Color, dark: Color) -> Color {
        Color(UIColor { trait in
            trait.userInterfaceStyle == .dark
                ? UIColor(dark)
                : UIColor(light)
        })
    }
}

// MARK: - Override ColorTheme with programmatic colors

extension ColorTheme {
    var backgroundAdaptive: Color {
        Color.adaptive(light: Color(hex: "#FFFFFF"), dark: Color(hex: "#0F0F0F"))
    }
    var surfaceAdaptive: Color {
        Color.adaptive(light: Color(hex: "#F5F5F5"), dark: Color(hex: "#1A1A1A"))
    }
    var primaryAdaptive: Color {
        Color.adaptive(light: Color(hex: "#0F0F0F"), dark: Color(hex: "#FFFFFF"))
    }
    var secondaryAdaptive: Color {
        Color.adaptive(light: Color(hex: "#6B6B6B"), dark: Color(hex: "#A0A0A0"))
    }
    var dividerAdaptive: Color {
        Color.adaptive(light: Color(hex: "#E0E0E0"), dark: Color(hex: "#2A2A2A"))
    }
}

