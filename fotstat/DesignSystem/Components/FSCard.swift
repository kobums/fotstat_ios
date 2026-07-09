import SwiftUI

/// 카드 컨테이너 공통 스타일: bgElev 배경 + 12 라운드 + 얇은 line 테두리.
/// 여러 화면에 흩어져 있던 `.background(t.bgElev).cornerRadius(12).overlay(스트로크)`
/// 체인을 한곳에 모은다.
struct FSCardModifier: ViewModifier {
    @Environment(\.fsTheme) private var t

    func body(content: Content) -> some View {
        content
            .background(t.bgElev)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.line, lineWidth: 0.5))
    }
}

extension View {
    /// 카드 컨테이너 스타일(bgElev + cornerRadius 12 + line stroke).
    func fsCard() -> some View { modifier(FSCardModifier()) }
}
