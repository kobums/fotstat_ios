import SwiftUI

struct FSStepper: View {
    let value: Int
    var suffix: String = ""
    var accent: Bool = false
    var small: Bool = false
    var canIncrement: Bool = true   // 상한 도달 시 +버튼 비활성(흐리게) 표시
    let onDecrement: () -> Void
    let onIncrement: () -> Void
    @Environment(\.fsTheme) var t

    private var btnSize: CGFloat { small ? 26 : 32 }
    private var fontSize: CGFloat { small ? 14 : 16 }
    // suffix("분" 등)가 붙으면 값 영역을 넓혀야 텍스트가 버튼 위로 넘치지 않는다.
    // suffix 사용처(훈련 시간)는 값이 3자리(300)까지 가므로 자릿수 여유분도 포함.
    private var valueWidth: CGFloat {
        let base: CGFloat = small ? 18 : 24
        let suffixExtra: CGFloat = suffix.isEmpty ? 0 : CGFloat(suffix.count) * fontSize + 18
        return base + suffixExtra
    }
    private let gap: CGFloat = 2
    // 콘텐츠 합과 정확히 일치하는 폭 → 압축으로 버튼이 값 위로 겹치는 현상 방지
    private var totalWidth: CGFloat { btnSize * 2 + valueWidth + gap * 2 }

    var body: some View {
        HStack(spacing: gap) {
            Button(action: onDecrement) {
                Text("−")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(t.text)
                    .frame(width: btnSize, height: btnSize)
                    .background(t.bgElev3)
                    .cornerRadius(small ? 8 : 10)
            }
            .buttonStyle(.plain)

            Text("\(value)\(suffix)")
                .font(.system(size: fontSize, weight: .black, design: .rounded))
                .foregroundColor(accent && value > 0 ? t.accent : t.text)
                .frame(minWidth: valueWidth)
                .multilineTextAlignment(.center)

            Button(action: onIncrement) {
                Text("+")
                    .font(.system(size: 17, weight: .bold, design: .rounded))
                    .foregroundColor(accent ? .white : t.text)
                    .frame(width: btnSize, height: btnSize)
                    .background(accent ? t.accent : t.bgElev3)
                    .cornerRadius(small ? 8 : 10)
            }
            .buttonStyle(.plain)
            .disabled(!canIncrement)
            .opacity(canIncrement ? 1 : 0.35)
        }
        .frame(width: totalWidth)
    }
}
