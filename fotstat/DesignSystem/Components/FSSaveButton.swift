import SwiftUI

/// 시트 헤더 우측의 "저장" 버튼.
/// 저장 중에는 스피너로 바뀌고 비활성화되어 진행 중임이 보이게 한다.
struct FSSaveButton: View {
    var title: String = "저장"
    let isSaving: Bool
    let action: () -> Void
    @Environment(\.fsTheme) var t

    var body: some View {
        Button(action: action) {
            // 텍스트를 투명하게 남겨 폭을 고정 — 스피너로 바뀌어도 헤더 타이틀이 밀리지 않는다
            Text(title)
                .font(.system(size: 17, weight: .semibold))
                .foregroundColor(t.accent)
                .opacity(isSaving ? 0 : 1)
                .overlay {
                    if isSaving {
                        ProgressView()
                            .controlSize(.small)
                            .tint(t.textSec)
                    }
                }
        }
        .disabled(isSaving)
        .accessibilityLabel(isSaving ? "저장 중" : title)
    }
}
