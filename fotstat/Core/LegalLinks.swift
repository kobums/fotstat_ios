import SwiftUI

/// 약관·개인정보 처리방침은 gowoobro.com에서 통합 호스팅한다(fotstat iOS = 프로젝트 16).
enum LegalLinks {
    static let terms = URL(string: "https://gowoobro.com/ko/app/16/terms")!
    static let privacy = URL(string: "https://gowoobro.com/ko/app/16/privacy")!
}

/// 가입·Apple 로그인·게스트 시작 전에 보여 주는 약관 동의 안내 한 줄.
struct FSLegalNotice: View {
    @Environment(\.fsTheme) var t

    private var notice: AttributedString {
        let markdown = "계속 진행하면 [이용약관](\(LegalLinks.terms.absoluteString))과 [개인정보 처리방침](\(LegalLinks.privacy.absoluteString))에 동의한 것으로 봅니다."
        return (try? AttributedString(markdown: markdown)) ?? AttributedString(markdown)
    }

    var body: some View {
        Text(notice)
            .font(.system(size: 12))
            .foregroundColor(t.textTer)
            .tint(t.textSec)
            .multilineTextAlignment(.center)
            .frame(maxWidth: .infinity)
    }
}
