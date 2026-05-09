import SwiftUI

struct FSPlayerAvatar: View {
    let number: Int?
    var size: CGFloat = 36
    @Environment(\.fsTheme) var t

    var body: some View {
        Circle()
            .fill(t.bgElev3)
            .frame(width: size, height: size)
            .overlay(
                Text(number.map { "\($0)" } ?? "-")
                    .font(.system(size: size * 0.42, weight: .bold, design: .rounded))
                    .foregroundColor(t.text)
                    .minimumScaleFactor(0.5)
            )
            .overlay(
                Circle().stroke(t.lineStrong, lineWidth: 0.5)
            )
    }
}
