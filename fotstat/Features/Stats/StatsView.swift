import SwiftUI

private let playingTimeEmptyHint = "경기 기록에서 출전 시간(분)을 입력하면\n선수별 출전 시간 순위가 표시됩니다"

// MARK: - TeamStatsContentView (Stats 탭)

struct TeamStatsContentView: View {
    let team: Team
    /// 리포트 탭과 공유하는 조회 기간 (TeamContextView 소유)
    @ObservedObject var period: StatsPeriod
    @StateObject private var vm: TeamStatsViewModel
    @Environment(\.fsTheme) var t
    // iPad(세로·가로 모두 regular)는 순위 3종을 가로 나란히 + 전체 펼침,
    // iPhone(compact)은 세로 스택 + top3 + 자세히 보기.
    @Environment(\.horizontalSizeClass) private var hSize

    init(team: Team, period: StatsPeriod) {
        self.team = team
        self.period = period
        _vm = StateObject(wrappedValue: TeamStatsViewModel(team: team))
    }

    var body: some View {
        statsBody(isWide: hSize == .regular)
    }

    private func statsBody(isWide: Bool) -> some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    FSTeamHeader(team: team, tab: .stats)

                    // 날짜 필터 — 재조회는 onChange(period.key) 한 곳에서 처리
                    DateRangeFilter(startDate: $period.startDate, endDate: $period.endDate) {}
                        .padding(.horizontal, 16)
                        .padding(.top, 14)

                    if vm.isLoading {
                        ProgressView().padding(.top, 40)
                    } else {
                        // 시즌 요약 타일 + 경기당 평균
                        StatsSummarySection(stats: vm.stats)
                            .padding(.top, 10)

                        // 이전 기간 대비 (직전 동일 길이 기간에 경기가 있을 때만)
                        if let stats = vm.stats, let prev = vm.prevStats, prev.matchCount > 0 {
                            FSSectionHeader(title: "이전 기간 대비")
                            HStack(spacing: 8) {
                                CompareTileView(label: "득점", value: stats.totalGoal,
                                                delta: stats.totalGoal - prev.totalGoal)
                                CompareTileView(label: "실점", value: stats.totalConceded,
                                                delta: stats.totalConceded - prev.totalConceded,
                                                goodWhenUp: false)
                                CompareTileView(label: "도움", value: stats.totalAssist,
                                                delta: stats.totalAssist - prev.totalAssist)
                            }
                            .padding(.horizontal, 16)
                        }

                        if let stats = vm.stats, stats.players.count >= 2 {
                            PlayerCompareSection(players: stats.players)
                        }

                        if let stats = vm.stats, !stats.players.isEmpty {
                            // iPad 가로: 득점 | 어시스트 | 출전 시간을 나란히, 전체 펼침
                            if isWide {
                                HStack(alignment: .top, spacing: 0) {
                                    VStack(spacing: 0) { goalRanking(stats, expanded: true) }
                                        .frame(maxWidth: .infinity, alignment: .top)
                                    VStack(spacing: 0) { assistRanking(stats, expanded: true) }
                                        .frame(maxWidth: .infinity, alignment: .top)
                                    VStack(spacing: 0) { minRanking(stats, expanded: true) }
                                        .frame(maxWidth: .infinity, alignment: .top)
                                }
                            } else {
                                goalRanking(stats, expanded: false)
                                assistRanking(stats, expanded: false)
                                minRanking(stats, expanded: false)
                            }
                        }
                    }
                }
                .padding(.bottom, 0)
            }
        }
        .background(t.bg.ignoresSafeArea())
        .task { await refetch() }
        // 리포트 탭에서 기간을 바꿔도 이 탭이 함께 갱신된다 (공유 StatsPeriod)
        .onChange(of: period.key) { _, _ in
            Task { await refetch() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .matchDeleted)) { _ in
            // 경기 삭제 시 경기 수·승패 요약이 stale해지지 않게 재집계 (리포트 탭과 동일)
            Task { await refetch() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .playerDeleted)) { _ in
            Task { await refetch() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .injuryChanged)) { _ in
            // 결장 경기 수가 부상 데이터 기반이라 부상 변경 시 재집계
            Task { await refetch() }
        }
    }

    private func refetch() async {
        await vm.fetch(start: period.startDate, end: period.endDate)
    }

    private func goalRanking(_ stats: TeamStats, expanded: Bool) -> some View {
        RankingSection(title: "득점 순위", players: stats.players,
            value: { $0.goal },
            valueLabel: { "\($0.goal)G" },
            subLabel: { "+\($0.assist)A" },
            expanded: expanded,
            raw: vm.raw)
    }

    private func assistRanking(_ stats: TeamStats, expanded: Bool) -> some View {
        RankingSection(title: "어시스트 순위", players: stats.players,
            value: { $0.assist },
            valueLabel: { "\($0.assist)A" },
            subLabel: { "\($0.goal)G" },
            expanded: expanded,
            raw: vm.raw)
    }

    private func minRanking(_ stats: TeamStats, expanded: Bool) -> some View {
        RankingSection(title: "출전 시간 순위", players: stats.players,
            value: { $0.min },
            valueLabel: { "\($0.min)'" },
            subLabel: { "\($0.games)경기 · \($0.goal)G \($0.assist)A" },
            emptyHint: playingTimeEmptyHint,
            expanded: expanded,
            raw: vm.raw)
    }
}

// MARK: - StatsView (전역 통계 탭)

struct StatsView: View {
    @StateObject private var vm = StatsViewModel()
    @Environment(\.fsTheme) var t

    var body: some View {
        ZStack {
            t.bg.ignoresSafeArea()

            if vm.isLoading {
                ProgressView()
            } else if vm.teams.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "chart.bar").font(.system(size: 48)).foregroundColor(t.textTer)
                    Text("팀을 먼저 추가하세요").font(.system(size: 17, weight: .semibold)).foregroundColor(t.textSec)
                }
            } else {
                ScrollView {
                    VStack(spacing: 0) {
                        // 헤더
                        HStack(alignment: .bottom) {
                            Text("통계").font(.system(size: 32, weight: .black)).foregroundColor(t.text)
                            Spacer()
                        }
                        .padding(.horizontal, 16).padding(.top, 60).padding(.bottom, 16)

                        // 팀 선택
                        if vm.teams.count > 1 {
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 8) {
                                    ForEach(vm.teams) { team in
                                        Button {
                                            vm.selectedTeamId = team.id
                                        } label: {
                                            Text(team.name)
                                                .font(.system(size: 13, weight: .semibold))
                                                .foregroundColor(vm.selectedTeamId == team.id ? .white : t.textSec)
                                                .padding(.horizontal, 14).padding(.vertical, 8)
                                                .background(vm.selectedTeamId == team.id ? t.accent : t.bgElev)
                                                .cornerRadius(20)
                                                .overlay(RoundedRectangle(cornerRadius: 20).stroke(t.line, lineWidth: 0.5))
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                            .padding(.bottom, 12)
                        }

                        // 날짜 필터
                        DateRangeFilter(startDate: $vm.startDate, endDate: $vm.endDate) {
                            Task { await vm.fetchStats() }
                        }
                        .padding(.horizontal, 16)
                        .padding(.bottom, 8)

                        if let stats = vm.teamStats {
                            StatsSummarySection(stats: stats)

                            RankingSection(title: "득점 순위", players: stats.players,
                                value: { $0.goal },
                                valueLabel: { "\($0.goal)G" },
                                subLabel: { "+\($0.assist)A" },
                                raw: vm.raw)
                            RankingSection(title: "어시스트 순위", players: stats.players,
                                value: { $0.assist },
                                valueLabel: { "\($0.assist)A" },
                                subLabel: { "\($0.goal)G" },
                                raw: vm.raw)
                            RankingSection(title: "출전 시간 순위", players: stats.players,
                                value: { $0.min },
                                valueLabel: { "\($0.min)'" },
                                subLabel: { "\($0.games)경기 · \($0.goal)G \($0.assist)A" },
                                emptyHint: playingTimeEmptyHint,
                                raw: vm.raw)
                        } else if vm.isLoadingStats {
                            ProgressView().padding(.top, 40)
                        }
                    }
                    .padding(.bottom, 0)
                }
            }
        }
        .task { await vm.fetchTeams() }
    }
}

// MARK: - StatsSummarySection (시즌 요약 + 실점·득실차 + 경기당 평균)

private func fsSigned(_ n: Int) -> String { n > 0 ? "+\(n)" : "\(n)" }
private func fsPerGame(_ total: Int, _ games: Int) -> String {
    games > 0 ? String(format: "%.1f", Double(total) / Double(games)) : "0.0"
}

struct StatsSummarySection: View {
    let stats: TeamStats?
    @Environment(\.fsTheme) var t

    var body: some View {
        let matchCount = stats?.matchCount ?? 0
        let wins = stats?.wins ?? 0
        let goal = stats?.totalGoal ?? 0
        let assist = stats?.totalAssist ?? 0
        let conceded = stats?.totalConceded ?? 0
        let diff = goal - conceded
        let winRate = matchCount > 0 ? Int(Double(wins) / Double(matchCount) * 100) : 0

        VStack(spacing: 0) {
            VStack(spacing: 8) {
                HStack(spacing: 8) {
                    FSStatTile(label: "시즌 골", value: "\(goal)", sub: "\(matchCount)경기", accent: true)
                    FSStatTile(label: "도움", value: "\(assist)", sub: "어시스트")
                    FSStatTile(label: "승률", value: "\(winRate)%",
                               sub: "W\(wins) D\(stats?.draws ?? 0) L\(stats?.losses ?? 0)")
                }
                HStack(spacing: 8) {
                    FSStatTile(label: "실점", value: "\(conceded)", sub: "\(matchCount)경기")
                    FSStatTile(label: "득실차", value: fsSigned(diff), sub: "득점-실점")
                }
            }
            .padding(.horizontal, 16)

            // 경기당 평균 (웹과 동일: 골·실점·도움·득실차)
            if matchCount > 0 {
                FSSectionHeader(title: "경기당 평균")
                HStack(spacing: 8) {
                    FSStatTile(label: "골", value: fsPerGame(goal, matchCount), sub: "경기당")
                    FSStatTile(label: "실점", value: fsPerGame(conceded, matchCount), sub: "경기당")
                    FSStatTile(label: "도움", value: fsPerGame(assist, matchCount), sub: "경기당")
                    FSStatTile(label: "득실차", value: fsPerGame(diff, matchCount), sub: "경기당")
                }
                .padding(.horizontal, 16)
            }
        }
    }
}

// MARK: - CompareTileView (이전 기간 대비)

struct CompareTileView: View {
    let label: String
    let value: Int
    /// 현재 - 이전
    let delta: Int
    /// 증가가 좋은 방향인지 — 실점은 false
    var goodWhenUp: Bool = true
    @Environment(\.fsTheme) var t

    var body: some View {
        let flat = delta == 0
        let up = delta > 0
        let good = flat ? false : up == goodWhenUp
        let deltaColor = flat ? t.textTer : (good ? t.pos : t.neg)

        VStack(alignment: .leading, spacing: 4) {
            Text(label.uppercased())
                .font(.system(size: 11, weight: .bold))
                .kerning(0.6)
                .foregroundColor(t.textTer)
            Text("\(value)")
                .font(.system(size: 28, weight: .bold, design: .rounded))
                .foregroundColor(t.text)
                .minimumScaleFactor(0.6)
            HStack(spacing: 3) {
                Image(systemName: flat ? "minus" : (up ? "arrow.up" : "arrow.down"))
                    .font(.system(size: 10, weight: .bold))
                Text(flat ? "변화 없음" : "\(abs(delta))")
                    .font(.system(size: 11, weight: .bold, design: .rounded))
            }
            .foregroundColor(deltaColor)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .background(t.bgElev)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.line, lineWidth: 0.5))
    }
}

// MARK: - PlayerCompareSection (선수 2명 비교)

struct PlayerCompareSection: View {
    let players: [PlayerStats]
    @State private var idA: Int
    @State private var idB: Int
    @Environment(\.fsTheme) var t

    init(players: [PlayerStats]) {
        self.players = players
        _idA = State(initialValue: players.first?.id ?? 0)
        _idB = State(initialValue: players.count > 1 ? players[1].id : players.first?.id ?? 0)
    }

    private func perGameGoal(_ p: PlayerStats?) -> Double {
        guard let p, p.games > 0 else { return 0 }
        return Double(p.goal) / Double(p.games)
    }

    var body: some View {
        // 통계 갱신으로 선택했던 선수가 사라지면 첫 선수로 대체
        let a = players.first { $0.id == idA } ?? players.first
        let b = players.first { $0.id == idB } ?? (players.count > 1 ? players[1] : players.first)
        let rows: [(label: String, a: Double, b: Double, fmt: (Double) -> String)] = [
            ("경기", Double(a?.games ?? 0), Double(b?.games ?? 0), { "\(Int($0))" }),
            ("골", Double(a?.goal ?? 0), Double(b?.goal ?? 0), { "\(Int($0))" }),
            ("도움", Double(a?.assist ?? 0), Double(b?.assist ?? 0), { "\(Int($0))" }),
            ("출전(분)", Double(a?.min ?? 0), Double(b?.min ?? 0), { "\(Int($0))" }),
            ("경기당 골", perGameGoal(a), perGameGoal(b), { String(format: "%.2f", $0) }),
        ]

        FSSectionHeader(title: "선수 비교")
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                playerHead(player: a, selection: $idA)
                Text("vs")
                    .font(.system(size: 11, weight: .black))
                    .foregroundColor(t.textTer)
                playerHead(player: b, selection: $idB)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)

            Divider().background(t.line)

            ForEach(Array(rows.enumerated()), id: \.offset) { i, row in
                HStack {
                    Text(row.fmt(row.a))
                        .font(.system(size: 15, weight: row.a > row.b ? .black : .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(row.a > row.b ? t.accent : t.text)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    Text(row.label)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(t.textSec)
                    Text(row.fmt(row.b))
                        .font(.system(size: 15, weight: row.b > row.a ? .black : .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundColor(row.b > row.a ? t.accent : t.text)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 9)
                if i < rows.count - 1 {
                    Divider().background(t.line)
                }
            }
        }
        .background(t.bgElev)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.line, lineWidth: 0.5))
        .padding(.horizontal, 16)
        // 선택했던 선수가 목록에서 사라지면 Picker 선택값도 함께 되돌린다 (invalid selection 경고 방지)
        .onChange(of: players.map(\.id)) { _, ids in
            if !ids.contains(idA) { idA = ids.first ?? 0 }
            if !ids.contains(idB) { idB = ids.count > 1 ? ids[1] : (ids.first ?? 0) }
        }
    }

    private func playerHead(player: PlayerStats?, selection: Binding<Int>) -> some View {
        HStack(spacing: 8) {
            FSPlayerAvatar(number: player?.number, size: 32)
            Picker("비교할 선수", selection: selection) {
                ForEach(players) { p in
                    Text("\(p.number.map { "\($0). " } ?? "")\(p.name)").tag(p.id)
                }
            }
            .pickerStyle(.menu)
            .tint(t.text)
            .labelsHidden()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - StatRankRow

struct StatRankRow: View {
    // nil = 기록 없음(순위 대신 "-" 표시)
    let rank: Int?
    let player: PlayerStats
    let value: Int
    let maxValue: Int
    let valueLabel: String
    let subLabel: String
    @Environment(\.fsTheme) var t

    var body: some View {
        HStack(spacing: 10) {
            Text(rank.map(String.init) ?? "-")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundColor(rank == 1 ? t.accent : t.textSec)
                .frame(minWidth: 24, alignment: .trailing)

            FSPlayerAvatar(number: player.number, size: 30)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(player.name).font(.system(size: 13, weight: .bold)).foregroundColor(t.text).lineLimit(1)
                    if let pos = player.position { FSPosChip(pos: pos) }
                }
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(t.bgElev3).frame(height: 5)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(rank == 1 ? t.accent : t.text.opacity(0.3 + 0.4 * Double(maxValue - value) / Double(max(maxValue, 1))))
                            .frame(width: geo.size.width * CGFloat(value) / CGFloat(max(maxValue, 1)), height: 5)
                    }
                }
                .frame(height: 5)
            }
            .frame(maxWidth: .infinity)

            Text(valueLabel)
                .font(.system(size: 18, weight: .black, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundColor(rank == 1 ? t.accent : t.text)

            Text(subLabel)
                .font(.system(size: 10))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
                .foregroundColor(t.textTer)
                .frame(minWidth: 36, alignment: .trailing)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }
}

// MARK: - RankingSection

struct RankingSection: View {
    let title: String
    let players: [PlayerStats]
    let value: (PlayerStats) -> Int
    let valueLabel: (PlayerStats) -> String
    let subLabel: (PlayerStats) -> String
    var emptyHint: String? = nil
    /// true면 스쿼드 전원(기록 0 포함)을 인라인으로 펼치고 '자세히 보기'를 숨긴다 (리포트 탭).
    var expanded: Bool = false
    /// 선수 상세의 경기별 기록·부상 섹션용 원본. nil이면 해당 섹션은 표시하지 않는다.
    var raw: TeamStatsRaw? = nil
    @State private var selectedPlayer: PlayerStats? = nil
    @State private var showAll = false
    @Environment(\.fsTheme) var t

    var body: some View {
        // 자세히 보기는 기록 0인 선수까지 스쿼드 전원을 보여준다 (웹과 동일)
        let allRanked = players.sorted { value($0) > value($1) }
        let ranked = allRanked.filter { value($0) > 0 }
        let maxVal = ranked.first.map { value($0) } ?? 1
        let top = expanded ? allRanked : Array(ranked.prefix(3))

        if !ranked.isEmpty {
            FSSectionHeader(title: title)
            VStack(spacing: 0) {
                ForEach(Array(top.enumerated()), id: \.element.id) { i, player in
                    Button { selectedPlayer = player } label: {
                        StatRankRow(
                            // 기록이 없는 선수는 순위 대신 "-" (RankingAllSheet와 동일)
                            rank: value(player) > 0 ? i + 1 : nil,
                            player: player,
                            value: value(player),
                            maxValue: maxVal,
                            valueLabel: valueLabel(player),
                            subLabel: subLabel(player)
                        )
                    }
                    .buttonStyle(.plain)
                    if i < top.count - 1 {
                        Divider().background(t.line)
                    }
                }
                if !expanded && allRanked.count > top.count {
                    Divider().background(t.line)
                    Button { showAll = true } label: {
                        HStack(spacing: 4) {
                            Text("자세히 보기")
                                .font(.system(size: 13, weight: .semibold))
                                .foregroundColor(t.accent)
                            Image(systemName: "chevron.right")
                                .font(.system(size: 11, weight: .semibold))
                                .foregroundColor(t.accent)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                    }
                }
            }
            .background(t.bgElev)
            .cornerRadius(12)
            .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.line, lineWidth: 0.5))
            .padding(.horizontal, 16)
            .sheet(item: $selectedPlayer) { player in
                PlayerStatDetailView(player: player, allPlayers: players, raw: raw)
                    .environment(\.fsTheme, t)
            }
            .sheet(isPresented: $showAll) {
                RankingAllSheet(
                    title: title, ranked: allRanked, maxVal: maxVal,
                    value: value, valueLabel: valueLabel, subLabel: subLabel,
                    allPlayers: players, raw: raw
                )
                .environment(\.fsTheme, t)
            }
        } else if let hint = emptyHint {
            FSSectionHeader(title: title)
            Text(hint)
                .font(.system(size: 13))
                .foregroundColor(t.textSec)
                .multilineTextAlignment(.center)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 20)
                .background(t.bgElev)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.line, lineWidth: 0.5))
                .padding(.horizontal, 16)
        }
    }
}

// MARK: - RankingAllSheet

struct RankingAllSheet: View {
    let title: String
    let ranked: [PlayerStats]
    let maxVal: Int
    let value: (PlayerStats) -> Int
    let valueLabel: (PlayerStats) -> String
    let subLabel: (PlayerStats) -> String
    let allPlayers: [PlayerStats]
    var raw: TeamStatsRaw? = nil
    @State private var selectedPlayer: PlayerStats? = nil
    @Environment(\.fsTheme) var t
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(t.textTer).frame(width: 36, height: 4)
                .padding(.top, 12).padding(.bottom, 16)
            HStack {
                Text(title)
                    .font(.system(size: 18, weight: .black))
                    .foregroundColor(t.text)
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
            .padding(.horizontal, 20).padding(.bottom, 16)

            ScrollView {
                VStack(spacing: 0) {
                    ForEach(Array(ranked.enumerated()), id: \.element.id) { i, player in
                        Button { selectedPlayer = player } label: {
                            StatRankRow(
                                rank: value(player) > 0 ? i + 1 : nil,
                                player: player,
                                value: value(player),
                                maxValue: maxVal,
                                valueLabel: valueLabel(player),
                                subLabel: subLabel(player)
                            )
                        }
                        .buttonStyle(.plain)
                        if i < ranked.count - 1 {
                            Divider().background(t.line)
                        }
                    }
                }
                .background(t.bgElev)
                .cornerRadius(12)
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.line, lineWidth: 0.5))
                .padding(.horizontal, 16)
                .padding(.bottom, 24)
            }
        }
        .background(t.bg.ignoresSafeArea())
        .presentationDetents([.large])
        .presentationDragIndicator(.hidden)
        .sheet(item: $selectedPlayer) { player in
            PlayerStatDetailView(player: player, allPlayers: allPlayers, raw: raw)
                .environment(\.fsTheme, t)
        }
    }
}
