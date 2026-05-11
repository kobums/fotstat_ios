import SwiftUI

struct FSResultPill: View {
    let result: String // "W", "D", "L"
    var size: CGFloat = 18
    @Environment(\.fsTheme) var t

    var color: Color {
        switch result {
        case "W": return t.pos
        case "L": return t.neg
        default:  return t.neu
        }
    }

    var body: some View {
        Text(result)
            .font(.system(size: size * 0.55, weight: .black))
            .foregroundColor(t.mode == .dark ? Color(hex: "0A0A0B") : .white)
            .frame(width: size, height: size)
            .background(color)
            .cornerRadius(4)
    }
}
