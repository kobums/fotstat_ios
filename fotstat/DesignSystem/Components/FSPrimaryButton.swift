import SwiftUI

/// 인증 화면의 기본 강조 버튼: accent 배경 + 흰 텍스트, isLoading 이면 ProgressView.
/// 로그인·회원가입·업그레이드 CTA 가 공유한다.
struct FSPrimaryButton: View {
    @Environment(\.fsTheme) private var t
    let title: String
    let isLoading: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            ZStack {
                if isLoading { ProgressView().tint(.white) }
                else { Text(title).font(.system(size: 16, weight: .bold)) }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity).frame(height: 52)
            .background(t.accent).cornerRadius(14)
            .shadow(color: t.accent.opacity(0.3), radius: 8, x: 0, y: 4)
        }
        .disabled(isLoading).padding(.top, 6)
    }
}
