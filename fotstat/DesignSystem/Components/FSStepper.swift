import SwiftUI

struct FSStepper: View {
    let value: Int
    var suffix: String = ""
    var accent: Bool = false
    var small: Bool = false
    let onDecrement: () -> Void
    let onIncrement: () -> Void
    @Environment(\.fsTheme) var t

    private var btnSize: CGFloat { small ? 30 : 34 }
    private var fontSize: CGFloat { small ? 14 : 16 }

    var body: some View {
        HStack(spacing: 0) {
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
                .frame(minWidth: small ? 24 : 28)
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
        }
        .frame(width: small ? 70 : 78)
    }
}
