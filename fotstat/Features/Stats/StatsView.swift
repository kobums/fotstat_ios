import SwiftUI

private let playingTimeEmptyHint = "경기 기록에서 출전 시간(분)을 입력하면\n선수별 출전 시간 순위가 표시됩니다"

// MARK: - TeamStatsContentView (Stats 탭)

struct TeamStatsContentView: View {
    let team: Team
    @StateObject private var vm: TeamStatsViewModel
    @Environment(\.fsTheme) var t

    init(team: Team) {
        self.team = team
        _vm = StateObject(wrappedValue: TeamStatsViewModel(team: team))
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    FSTeamHeader(team: team, tab: .stats)

                    // 날짜 필터
                    DateRangeFilter(startDate: $vm.startDate, endDate: $vm.endDate) {
                        Task { await vm.fetch() }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 14)

                    if vm.isLoading {
                        ProgressView().padding(.top, 40)
                    } else {
                        // 시즌 요약 타일
                        let matchCount = vm.stats?.matchCount ?? 0
                        let winRate = matchCount > 0 ? Int(Double(vm.stats?.wins ?? 0) / Double(matchCount) * 100) : 0
                        HStack(spacing: 8) {
                            FSStatTile(label: "시즌 골", value: "\(vm.stats?.totalGoal ?? 0)", sub: "\(matchCount)경기", accent: true)
                            FSStatTile(label: "도움", value: "\(vm.stats?.totalAssist ?? 0)", sub: "어시스트")
                            FSStatTile(label: "승률", value: "\(winRate)%",
                                       sub: "W\(vm.stats?.wins ?? 0) D\(vm.stats?.draws ?? 0) L\(vm.stats?.losses ?? 0)")
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 10)

                        if let stats = vm.stats, !stats.players.isEmpty {
                            RankingSection(title: "득점 순위", players: stats.players,
                                value: { $0.goal },
                                valueLabel: { "\($0.goal)G" },
                                subLabel: { "+\($0.assist)A" })
                            RankingSection(title: "어시스트 순위", players: stats.players,
                                value: { $0.assist },
                                valueLabel: { "\($0.assist)A" },
                                subLabel: { "\($0.goal)G" })
                            RankingSection(title: "출전 시간 순위", players: stats.players,
                                value: { $0.min },
                                valueLabel: { "\($0.min)'" },
                                subLabel: { "\($0.goal)G \($0.assist)A" },
                                emptyHint: playingTimeEmptyHint)
                        }
                    }
                }
                .padding(.bottom, 0)
            }
        }
        .background(t.bg.ignoresSafeArea())
        .task { await vm.fetch() }
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
                            let winRate = stats.matchCount > 0 ? Int(Double(stats.wins) / Double(stats.matchCount) * 100) : 0
                            HStack(spacing: 8) {
                                FSStatTile(label: "시즌 골", value: "\(stats.totalGoal)", sub: "\(stats.matchCount)경기", accent: true)
                                FSStatTile(label: "도움", value: "\(stats.totalAssist)", sub: "어시스트")
                                FSStatTile(label: "승률", value: "\(winRate)%",
                                           sub: "W\(stats.wins) D\(stats.draws) L\(stats.losses)")
                            }
                            .padding(.horizontal, 16)

                            RankingSection(title: "득점 순위", players: stats.players,
                                value: { $0.goal },
                                valueLabel: { "\($0.goal)G" },
                                subLabel: { "+\($0.assist)A" })
                            RankingSection(title: "어시스트 순위", players: stats.players,
                                value: { $0.assist },
                                valueLabel: { "\($0.assist)A" },
                                subLabel: { "\($0.goal)G" })
                            RankingSection(title: "출전 시간 순위", players: stats.players,
                                value: { $0.min },
                                valueLabel: { "\($0.min)'" },
                                subLabel: { "\($0.goal)G \($0.assist)A" },
                                emptyHint: playingTimeEmptyHint)
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

// MARK: - StatRankRow

struct StatRankRow: View {
    let rank: Int
    let player: PlayerStats
    let value: Int
    let maxValue: Int
    let valueLabel: String
    let subLabel: String
    @Environment(\.fsTheme) var t

    var body: some View {
        HStack(spacing: 10) {
            Text("\(rank)")
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(rank == 1 ? t.accent : t.textSec)
                .frame(width: 16)

            FSPlayerAvatar(number: player.number, size: 30)

            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    Text(player.name).font(.system(size: 13, weight: .bold)).foregroundColor(t.text)
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
                .foregroundColor(rank == 1 ? t.accent : t.text)

            Text(subLabel)
                .font(.system(size: 10))
                .foregroundColor(t.textTer)
                .frame(width: 36, alignment: .trailing)
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
    @State private var selectedPlayer: PlayerStats? = nil
    @State private var showAll = false
    @Environment(\.fsTheme) var t

    var body: some View {
        let ranked = players.filter { value($0) > 0 }.sorted { value($0) > value($1) }
        let maxVal = ranked.first.map { value($0) } ?? 1
        let top = Array(ranked.prefix(3))

        if !ranked.isEmpty {
            FSSectionHeader(title: title)
            VStack(spacing: 0) {
                ForEach(Array(top.enumerated()), id: \.element.id) { i, player in
                    Button { selectedPlayer = player } label: {
                        StatRankRow(
                            rank: i + 1,
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
                if ranked.count > 3 {
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
                PlayerStatDetailView(player: player, allPlayers: players)
                    .environment(\.fsTheme, t)
            }
            .sheet(isPresented: $showAll) {
                RankingAllSheet(
                    title: title, ranked: ranked, maxVal: maxVal,
                    value: value, valueLabel: valueLabel, subLabel: subLabel,
                    allPlayers: players
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
                                rank: i + 1,
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
            PlayerStatDetailView(player: player, allPlayers: allPlayers)
                .environment(\.fsTheme, t)
        }
    }
}
