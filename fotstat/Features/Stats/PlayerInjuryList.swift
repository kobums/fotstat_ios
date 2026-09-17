import SwiftUI

/// 선수 부상 이력 — 종류 · 기간 · 진행 중 배지. 통계 탭 시트와 선수 상세가 공유한다.
/// 목록은 이미 선수별로 걸러 최근순 정렬된 상태(playerInjuries(_:playerId:))로 넘긴다.
struct PlayerInjuryList: View {
    let injuries: [Injury]
    var emptyText = "부상 이력이 없습니다"
    @Environment(\.fsTheme) var t

    var body: some View {
        if injuries.isEmpty {
            Text(emptyText)
                .font(.system(size: 13))
                .foregroundColor(t.textTer)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 12).padding(.vertical, 14)
                .fsCard()
        } else {
            VStack(spacing: 0) {
                ForEach(Array(injuries.enumerated()), id: \.element.id) { i, inj in
                    HStack(spacing: 8) {
                        Text(inj.type?.isEmpty == false ? inj.type! : "부상")
                            .font(.system(size: 13, weight: .bold)).foregroundColor(t.text)
                        Text("\(PlayerMatchLogCard.shortDate(inj.startdate ?? "")) ~ \(inj.isActive ? "진행 중" : PlayerMatchLogCard.shortDate(inj.returndate ?? ""))")
                            .font(.system(size: 12)).monospacedDigit().foregroundColor(t.textTer)
                        Spacer()
                        if inj.isActive {
                            Text("부상 중")
                                .font(.system(size: 10, weight: .bold)).foregroundColor(t.neg)
                                .padding(.horizontal, 6).padding(.vertical, 2)
                                .background(t.neg.opacity(0.14)).cornerRadius(4)
                        }
                    }
                    .padding(.horizontal, 12).padding(.vertical, 10)
                    if i < injuries.count - 1 { Divider().background(t.line) }
                }
            }
            .fsCard()
        }
    }
}
