import SwiftUI

struct FSStatTile: View {
    let label: String
    let value: String
    var sub: String? = nil
    var accent: Bool = false
    @Environment(\.fsTheme) var t

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold))
                .kerning(0.6)
                .foregroundColor(t.textTer)
            Text(value)
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(accent ? t.accent : t.text)
                .minimumScaleFactor(0.6)
            if let sub {
                Text(sub)
                    .font(.system(size: 11))
                    .foregroundColor(t.textSec)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(t.bgElev)
        .cornerRadius(14)
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(t.line, lineWidth: 0.5)
        )
    }
}
