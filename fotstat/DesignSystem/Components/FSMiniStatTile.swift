import SwiftUI

/// 요약 타일의 컴팩트 버전 — 값(22pt) 위, 라벨 아래. 선수 상세·통계 시트의
/// 미니 타일 행에서 공유한다 (FSStatTile은 라벨 위·값 28pt의 큰 타일).
struct FSMiniStatTile: View {
    let label: String
    let value: String
    var sub: String? = nil
    var accent: Bool = false
    @Environment(\.fsTheme) var t

    init(_ label: String, value: String, sub: String? = nil, accent: Bool = false) {
        self.label = label
        self.value = value
        self.sub = sub
        self.accent = accent
    }

    init(_ label: String, value: Int, suffix: String = "", sub: String? = nil, accent: Bool = false) {
        self.init(label, value: "\(value)\(suffix)", sub: sub, accent: accent && value > 0)
    }

    var body: some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(accent ? t.accent : t.text)
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .kerning(0.4)
                .foregroundColor(t.textTer)
                .lineLimit(1)
            if let sub {
                Text(sub)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(t.textSec)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .padding(.horizontal, 4)
        .fsCard()
    }
}
