import SwiftUI

struct PlayerStatDetailView: View {
    let player: PlayerStats
    let allPlayers: [PlayerStats]
    /// 경기별 기록·부상 섹션용 원본. nil이면 해당 섹션은 숨긴다.
    var raw: TeamStatsRaw? = nil
    @Environment(\.fsTheme) var t
    @Environment(\.dismiss) var dismiss
    // 실제 가용 폭 기준 — 아이패드 Split View 등 좁은 창에서는 세로 스택으로 폴백.
    @Environment(\.horizontalSizeClass) private var hSize

    private func avg(_ kp: KeyPath<PlayerStats, Int>) -> Double {
        guard !allPlayers.isEmpty else { return 0 }
        return Double(allPlayers.reduce(0) { $0 + $1[keyPath: kp] }) / Double(allPlayers.count)
    }

    // 상위 X%: X = (rank / total) * 100, rank 1 = 상위 X%가 가장 낮음
    private func topPct(_ kp: KeyPath<PlayerStats, Int>) -> Int {
        let v = player[keyPath: kp]
        let total = allPlayers.count
        guard total > 0 else { return 100 }
        let better = allPlayers.filter { $0[keyPath: kp] > v }.count
        return max(1, Int(ceil(Double(better + 1) / Double(total) * 100)))
    }

    var body: some View {
        let logs = raw.map { playerMatchLogs($0, playerId: player.id) } ?? []
        let injuries = raw.map { playerInjuries($0, playerId: player.id) } ?? []
        // 2단은 아이패드 + 가로 폭이 넉넉할 때만 (Split View 좁은 창·아이폰 가로는 세로 스택)
        let twoCol = Self.isPad && hSize == .regular
        let content = VStack(spacing: 0) {
            Capsule().fill(t.textTer).frame(width: 36, height: 4)
                .padding(.top, 12).padding(.bottom, 20)

            // 선수 헤더
            HStack(spacing: 14) {
                FSPlayerAvatar(number: player.number, size: 52)
                VStack(alignment: .leading, spacing: 6) {
                    Text(player.name)
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(t.text)
                    if let pos = player.position { FSPosChip(pos: pos) }
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(t.textSec)
                        .frame(width: 28, height: 28)
                        .background(t.bgElev3)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)

            ScrollView {
                if twoCol {
                    // 넓은 화면: 왼쪽 선수 정보 | 오른쪽 경기별 기록
                    HStack(alignment: .top, spacing: 8) {
                        infoColumn(injuries)
                            .frame(maxWidth: .infinity, alignment: .top)
                        logsColumn(logs)
                            .frame(maxWidth: .infinity, alignment: .top)
                    }
                    .padding(.bottom, 24)
                } else {
                    // 좁은 화면: 세로 스택 (선수 정보 → 경기별 기록)
                    VStack(spacing: 0) {
                        infoColumn(injuries)
                        logsColumn(logs).padding(.top, 20)
                    }
                    .padding(.bottom, 24)
                }
            }
        }
        .background(t.bg.ignoresSafeArea())

        if Self.isPad {
            // 아이패드는 넓은 페이지 시트로 2단이 들어가게 한다
            content
                .presentationSizing(.page)
                .presentationDragIndicator(.hidden)
        } else {
            content
                .presentationDetents([.fraction(0.72), .large])
                .presentationDragIndicator(.hidden)
        }
    }

    // MARK: - 좌/우 컬럼

    /// 왼쪽(또는 아이폰 상단): 선수 정보 — 미니 타일 · 팀 평균 비교 · 부상 이력.
    private func infoColumn(_ injuries: [Injury]) -> some View {
        VStack(spacing: 0) {
            miniTilesRow
            compareCard
            if !injuries.isEmpty {
                injurySection(injuries).padding(.top, 20)
            }
        }
    }

    /// 오른쪽(아이패드): 경기별 기록. 출전 경기가 없으면 안내.
    @ViewBuilder
    private func logsColumn(_ logs: [PlayerMatchLog]) -> some View {
        if logs.isEmpty {
            Text("이 기간에 출전한 경기가 없습니다")
                .font(.system(size: 13))
                .foregroundColor(t.textTer)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 40)
                .padding(.horizontal, 16)
        } else {
            matchLogSection(logs)
        }
    }

    private var miniTilesRow: some View {
        HStack(spacing: 8) {
            miniTile("골", value: player.goal, accent: true)
            miniTile("도움", value: player.assist)
            miniTile("출전 분", value: player.min, suffix: "'")
            miniTile("경기", value: player.games)
            if player.absentGames > 0 {
                miniTile("결장", value: player.absentGames)
            }
        }
        .padding(.horizontal, 16)
        .padding(.bottom, 20)
    }

    private var compareCard: some View {
        VStack(spacing: 0) {
            HStack {
                Text("팀 평균 비교")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(0.5)
                    .foregroundColor(t.textTer)
                Spacer()
                HStack(spacing: 6) {
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(t.accent).frame(width: 12, height: 4)
                        Text("이 선수").font(.system(size: 10)).foregroundColor(t.textSec)
                    }
                    HStack(spacing: 4) {
                        RoundedRectangle(cornerRadius: 2).fill(t.bgElev3).frame(width: 12, height: 4)
                        Text("팀 평균").font(.system(size: 10)).foregroundColor(t.textTer)
                    }
                }
            }
            .padding(.horizontal, 14).padding(.vertical, 10)
            .overlay(Rectangle().fill(t.line).frame(height: 0.5), alignment: .bottom)

            compRow(label: "골", kp: \.goal, suffix: "G", accent: true)
            Divider().background(t.line)
            compRow(label: "도움", kp: \.assist, suffix: "A")
            Divider().background(t.line)
            compRow(label: "출전 시간", kp: \.min, suffix: "'")
        }
        .background(t.bgElev)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.line, lineWidth: 0.5))
        .padding(.horizontal, 16)
    }

    private static let isPad = UIDevice.current.userInterfaceIdiom == .pad

    // MARK: - 경기별 기록 · 부상 이력

    private func matchLogSection(_ logs: [PlayerMatchLog]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("경기별 기록")
            ForEach(logs) { matchLogCard($0) }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }

    @ViewBuilder
    private func matchLogCard(_ log: PlayerMatchLog) -> some View {
        let totalCards = cardText(yellow: log.yellow, red: log.red)
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                Text(shortDate(log.matchdate))
                    .font(.system(size: 12, weight: .bold)).foregroundColor(t.textSec)
                Text("vs \(log.opponent)")
                    .font(.system(size: 13, weight: .semibold)).foregroundColor(t.text).lineLimit(1)
                Spacer()
                Text("\(log.home):\(log.away)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .monospacedDigit().foregroundColor(t.text)
                FSResultPill(result: log.result, label: log.resultLabel, size: 18)
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
        .background(t.bgElev)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.line, lineWidth: 0.5))
    }

    private func injurySection(_ injuries: [Injury]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("부상 이력")
            VStack(spacing: 0) {
                ForEach(Array(injuries.enumerated()), id: \.element.id) { i, inj in
                    HStack(spacing: 8) {
                        Text(inj.type?.isEmpty == false ? inj.type! : "부상")
                            .font(.system(size: 13, weight: .bold)).foregroundColor(t.text)
                        Text("\(shortDate(inj.startdate ?? "")) ~ \(inj.isActive ? "진행 중" : shortDate(inj.returndate ?? ""))")
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
            .background(t.bgElev)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.line, lineWidth: 0.5))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }

    private func sectionTitle(_ s: String) -> some View {
        HStack {
            Text(s)
                .font(.system(size: 11, weight: .bold)).kerning(0.5)
                .foregroundColor(t.textTer)
            Spacer()
        }
    }

    /// "yyyy-MM-dd HH:mm:ss" 또는 "yyyy-MM-dd" → "MM.dd"
    private func shortDate(_ s: String) -> String {
        let day = s.dayPrefix
        let comps = day.split(separator: "-")
        return comps.count == 3 ? "\(comps[1]).\(comps[2])" : day
    }

    /// 카드 표기: 0이면 빈칸, 1이면 아이콘만, 2+면 아이콘+개수.
    private func cardText(yellow: Int, red: Int) -> String {
        var parts: [String] = []
        if yellow > 0 { parts.append(yellow > 1 ? "🟨\(yellow)" : "🟨") }
        if red > 0 { parts.append(red > 1 ? "🟥\(red)" : "🟥") }
        return parts.joined(separator: " ")
    }

    @ViewBuilder
    private func miniTile(_ label: String, value: Int, suffix: String = "", accent: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text("\(value)\(suffix)")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(accent && value > 0 ? t.accent : t.text)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .kerning(0.4)
                .foregroundColor(t.textTer)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(t.bgElev)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.line, lineWidth: 0.5))
    }

    @ViewBuilder
    private func compRow(label: String, kp: KeyPath<PlayerStats, Int>, suffix: String, accent: Bool = false) -> some View {
        let val = Double(player[keyPath: kp])
        let avgVal = avg(kp)
        let pct = topPct(kp)
        let maxBar = max(val, avgVal, 1.0)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(t.text)
                Spacer()
                Text("\(Int(val))\(suffix)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(accent ? t.accent : t.text)
                Text("·")
                    .font(.system(size: 11))
                    .foregroundColor(t.textTer)
                Text(avgVal.truncatingRemainder(dividingBy: 1) < 0.05
                     ? "\(Int(avgVal))\(suffix)"
                     : String(format: "%.1f\(suffix)", avgVal))
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(t.textSec)
                Text("상위 \(pct)%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(t.accent)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(t.accentSoft).cornerRadius(4)
            }
            GeometryReader { geo in
                VStack(spacing: 3) {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(t.bgElev3).frame(height: 5)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(accent ? t.accent : t.text.opacity(0.5))
                            .frame(width: geo.size.width * CGFloat(val / maxBar), height: 5)
                    }
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(t.bgElev3).frame(height: 5)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(t.textTer)
                            .frame(width: geo.size.width * CGFloat(avgVal / maxBar), height: 5)
                    }
                }
            }
            .frame(height: 13)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}
