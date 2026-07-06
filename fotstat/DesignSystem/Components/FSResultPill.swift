import SwiftUI

struct FSResultPill: View {
    let result: String // "W", "D", "L" — 색상 판정 기준
    var label: String? = nil // 표시 텍스트 오버라이드 (예: "승"/"무"/"패")
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
        Text(label ?? result)
            .font(.system(size: size * 0.55, weight: .black))
            .foregroundColor(t.mode == .dark ? Color(hex: "0A0A0B") : .white)
            .frame(width: size, height: size)
            .background(color)
            .cornerRadius(4)
    }
}
