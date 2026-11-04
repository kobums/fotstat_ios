import SwiftUI

struct PlayerStatDetailView: View {
    let player: PlayerStats
    let allPlayers: [PlayerStats]
    /// 경기별 기록·부상 섹션용 원본. nil이면 해당 섹션은 숨긴다.
    var raw: TeamStatsRaw? = nil
    /// 넓은 페이지 시트로 띄울지 — 띄우는 쪽이 창 크기(fsContainerSize)로 정해 넘긴다.
    /// 시트 안에서 재면 시트 형태와 폭이 서로 물려 순환하므로 밖에서 결정한다.
    var presentsAsPage: Bool = false
    @Environment(\.fsTheme) var t
    @Environment(\.dismiss) var dismiss
    /// 실제 시트 폭 — 페이지 시트 안에서 2단/1단을 정한다.
    @State private var width: CGFloat = 0

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
        // 2단은 페이지 시트 + 시트 폭이 넉넉할 때만 (Split View 좁은 창·아이폰 가로는 세로 스택)
        let twoCol = presentsAsPage && width >= Self.twoColMinWidth
        // if/else로 나누면 접기/펼치기 때 뷰 identity가 바뀌어 스크롤이 초기화되므로 레이아웃만 교체
        let columns = twoCol
            ? AnyLayout(HStackLayout(alignment: .top, spacing: 8))
            : AnyLayout(VStackLayout(spacing: 0))
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
                // 넓은 화면: 왼쪽 선수 정보 | 오른쪽 경기별 기록
                // 좁은 화면: 세로 스택 (선수 정보 → 경기별 기록)
                columns {
                    infoColumn(injuries)
                        .frame(maxWidth: .infinity, alignment: .top)
                    logsColumn(logs)
                        .frame(maxWidth: .infinity, alignment: .top)
                        .padding(.top, twoCol ? 0 : 20)
                }
                .padding(.bottom, 24)
            }
        }
        .background(t.bg.ignoresSafeArea())
        .onGeometryChange(for: CGFloat.self) { $0.size.width } action: { width = $0 }

        if presentsAsPage {
            // 넓은 창(iPad·폴더블 펼침)은 페이지 시트로 2단이 들어가게 한다
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
            FSMiniStatTile("골", value: player.goal, accent: true)
            FSMiniStatTile("도움", value: player.assist)
            FSMiniStatTile("출전 분", value: player.min, suffix: "'")
            FSMiniStatTile("경기", value: player.games)
            if player.absentGames > 0 {
                FSMiniStatTile("결장", value: player.absentGames)
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

    /// 좌/우 컬럼이 각각 ~300pt 이상 확보되는 최소 시트 폭.
    private static let twoColMinWidth: CGFloat = 600

    // MARK: - 경기별 기록 · 부상 이력

    private func matchLogSection(_ logs: [PlayerMatchLog]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("경기별 기록")
            PlayerMatchLogList(logs: logs)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
    }

    private func injurySection(_ injuries: [Injury]) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("부상 이력")
            PlayerInjuryList(injuries: injuries)
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
                // 값이 0이면 순위를 매기지 않는다 — 전원 0일 때의 공동 1위 배지 방지(PlayerRank.label 과 같은 규칙)
                Text(val > 0 ? "상위 \(pct)%" : "-")
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
