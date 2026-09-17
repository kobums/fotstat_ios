import SwiftUI

/// 팀 내 위치 — fotmob "시즌 성적"의 순위 바를 팀 단위로. 지표마다 선수 값과
/// 스쿼드 1위 대비 비례 바, 팀 평균, 상위 %(작은 스쿼드는 순위)를 보여준다.
/// 웹 features/player/TeamRankCard 미러.
struct TeamRankCard: View {
    let playerId: Int
    let squad: [PlayerStats]
    /// 선수 id → 훈련 참석률(%). 주면 참석률 행이 붙는다.
    var attendance: [Int: Int]? = nil
    @State private var mode: RankMode = .total
    @Environment(\.fsTheme) var t

    private var metrics: [RankMetric] {
        PlayerRank.metrics(playerId: playerId, squad: squad, mode: mode, attendance: attendance)
    }

    var body: some View {
        let rows = metrics
        if !rows.isEmpty {
            VStack(spacing: 14) {
                HStack {
                    Text("팀 내 위치")
                        .font(.system(size: 11, weight: .bold))
                        .kerning(0.5)
                        .foregroundColor(t.textTer)
                    Spacer()
                    Picker("집계 기준", selection: $mode) {
                        ForEach(RankMode.allCases) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .frame(width: 140)
                }

                VStack(spacing: 12) {
                    ForEach(rows) { m in
                        rankRow(m)
                    }
                }
            }
            .padding(14)
            .fsCard()
        }
    }

    @ViewBuilder
    private func rankRow(_ m: RankMetric) -> some View {
        let ratio = CGFloat(min(1, max(0, m.value / m.max)))
        let top = m.rank == 1 && m.value > 0
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(m.label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(t.text)
                Spacer()
                Text(m.valueText)
                    .font(.system(size: 15, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(t.text)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3).fill(t.bgElev3)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(top ? t.accent : t.text.opacity(0.35))
                        .frame(width: geo.size.width * ratio)
                }
            }
            .frame(height: 5)
            HStack {
                Text("팀 평균 \(m.avgText)")
                    .font(.system(size: 11, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(t.textTer)
                Spacer()
                Text(PlayerRank.label(m))
                    .font(.system(size: 10, weight: .bold))
                    .monospacedDigit()
                    .foregroundColor(t.accent)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(t.accentSoft).cornerRadius(4)
            }
        }
    }
}
