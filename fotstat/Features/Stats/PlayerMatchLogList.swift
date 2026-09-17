import SwiftUI

/// 선수의 경기별 기록 목록 — 경기마다 날짜·상대·스코어·결과와 쿼터별 라인, 합계.
/// 통계 탭 시트(PlayerStatDetailView)와 선수 상세(PlayerDetailView)가 공유한다.
/// `matches`를 주면 카드가 NavigationLink(value: Match)가 되어 경기 상세로 들어간다
/// (NavigationStack 안에서만 — 시트에서는 nil로 둔다).
struct PlayerMatchLogList: View {
    let logs: [PlayerMatchLog]
    var matches: [Match]? = nil
    var emptyText = "이 기간에 출전한 경기가 없습니다"
    @Environment(\.fsTheme) var t

    private func match(for id: Int) -> Match? {
        matches?.first { $0.id == id }
    }

    var body: some View {
        if logs.isEmpty {
            Text(emptyText)
                .font(.system(size: 13))
                .foregroundColor(t.textTer)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .fsCard()
        } else {
            VStack(spacing: 8) {
                ForEach(logs) { log in
                    if let m = match(for: log.matchId) {
                        NavigationLink(value: m) {
                            PlayerMatchLogCard(log: log, linked: true)
                        }
                        .buttonStyle(.plain)
                    } else {
                        PlayerMatchLogCard(log: log, linked: false)
                    }
                }
            }
        }
    }
}

struct PlayerMatchLogCard: View {
    let log: PlayerMatchLog
    var linked = false
    @Environment(\.fsTheme) var t

    /// "yyyy-MM-dd HH:mm:ss" 또는 "yyyy-MM-dd" → "MM.dd"
    static func shortDate(_ s: String) -> String {
        let day = s.dayPrefix
        let comps = day.split(separator: "-")
        return comps.count == 3 ? "\(comps[1]).\(comps[2])" : day
    }

    var body: some View {
        let totalCards = cardText(yellow: log.yellow, red: log.red)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(Self.shortDate(log.matchdate))
                    .font(.system(size: 12, weight: .bold)).foregroundColor(t.textSec)
                Text("vs \(log.opponent)")
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(t.text).lineLimit(1)
                Spacer()
                Text("\(log.home):\(log.away)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit().foregroundColor(t.text)
                FSResultPill(result: log.result, label: log.resultLabel, size: 18)
                if linked {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(t.textTer)
                }
            }
            Divider().background(t.line)
            ForEach(log.quarters) { q in
                let cards = cardText(yellow: q.yellow, red: q.red)
                HStack(spacing: 8) {
                    Text("Q\(q.number)")
                        .font(.system(size: 12, weight: .bold)).foregroundColor(t.textSec)
                        .frame(width: 26, alignment: .leading)
                    Text("\(q.min)'")
                        .font(.system(size: 12)).monospacedDigit().foregroundColor(t.textTer)
                        .frame(width: 34, alignment: .leading)
                    Text("\(q.goal)G \(q.assist)A")
                        .font(.system(size: 12, weight: .semibold)).monospacedDigit().foregroundColor(t.text)
                    Spacer()
                    if !cards.isEmpty { Text(cards).font(.system(size: 11)) }
                }
            }
            Text("합계 \(log.min)' · \(log.goal)G \(log.assist)A" + (totalCards.isEmpty ? "" : " · \(totalCards)"))
                .font(.system(size: 12, weight: .bold)).foregroundColor(t.textSec)
                .padding(.top, 4)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .contentShape(Rectangle())
        .fsCard()
    }
}
