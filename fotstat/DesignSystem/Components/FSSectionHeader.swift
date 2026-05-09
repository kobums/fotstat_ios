import SwiftUI

struct FSSectionHeader: View {
    let title: String
    var action: String? = nil
    @Environment(\.fsTheme) var t

    var body: some View {
        HStack {
            Text(title.uppercased())
                .font(.system(size: 13, weight: .bold))
                .kerning(0.6)
                .foregroundColor(t.textSec)
            Spacer()
            if let action {
                Text(action)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(t.accent)
            }
        }
        .padding(.horizontal, 16)
        .padding(.top, 14)
        .padding(.bottom, 8)
    }
}
