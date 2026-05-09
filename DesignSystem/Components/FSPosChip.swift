import SwiftUI

struct FSPosChip: View {
    let pos: String

    var color: Color { fsPosColor(pos) }

    var body: some View {
        Text(pos)
            .font(.system(size: 10, weight: .black))
            .kerning(0.4)
            .foregroundColor(color)
            .padding(.horizontal, 6)
            .padding(.vertical, 2)
            .background(color.opacity(0.13))
            .cornerRadius(4)
    }
}
