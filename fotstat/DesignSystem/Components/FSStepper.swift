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
    private var valueWidth: CGFloat { small ? 18 : 24 }
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
