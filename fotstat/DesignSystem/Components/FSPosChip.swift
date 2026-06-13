import SwiftUI

struct FSPosChip: View {
    let pos: String

    private var trimmed: String { pos.trimmingCharacters(in: .whitespacesAndNewlines) }
    var color: Color { fsPosColor(trimmed) }

    var body: some View {
        // 포지션 미입력(빈 문자열/공백) 시 칸 자체를 그리지 않음
        if !trimmed.isEmpty {
            Text(trimmed)
                .font(.system(size: 10, weight: .black))
                .kerning(0.4)
                .foregroundColor(color)
                .padding(.horizontal, 6)
                .padding(.vertical, 2)
                .background(color.opacity(0.13))
                .cornerRadius(4)
        }
    }
}
