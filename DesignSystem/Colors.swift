import SwiftUI

extension Color {
    static let theme = ColorTheme()
}

struct ColorTheme {
    // 배경
    let background     = Color("Background")
    let surface        = Color("Surface")

    // 텍스트
    let primary        = Color("TextPrimary")
    let secondary      = Color("TextSecondary")

    // 구분선
    let divider        = Color("Divider")
}
