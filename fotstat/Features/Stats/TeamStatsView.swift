import Foundation
import Combine

// TeamStatsViewModel – shared by TeamStatsContentView (StatsView.swift)

@MainActor
final class TeamStatsViewModel: ObservableObject {
    @Published var stats: TeamStats?
    @Published var isLoading = false
    @Published var startDate: Date? = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))
    @Published var endDate: Date? = Date()

    let team: Team

    init(team: Team) {
        self.team = team
    }

    func fetch() async {
        isLoading = true
        defer { isLoading = false }
        stats = await loadStats(teamId: team.id, from: startDate, to: endDate)
    }
}

@MainActor
func loadStats(teamId: Int, from startDate: Date? = nil, to endDate: Date? = nil) async -> TeamStats? {
    async let playersReq = APIClient.shared.request(
        .players(teamId: teamId),
        responseType: ItemsResponse<Player>.self
    )
    async let matchesReq = APIClient.shared.request(
        .matches(teamId: teamId),
        responseType: ItemsResponse<Match>.self
    )
    guard let (playersResp, matchesResp) = try? await (playersReq, matchesReq) else { return nil }

    let players = playersResp.items ?? []
    var finished = (matchesResp.items ?? []).filter { ($0.parsedDate ?? .distantFuture) <= Date() }
    if let s = startDate {
        finished = finished.filter { ($0.parsedDate ?? .distantPast) >= s }
    }
    if let e = endDate {
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: e) ?? e
        finished = finished.filter { ($0.parsedDate ?? .distantFuture) <= endOfDay }
    }

    // match → quarter, track quarterMatchMap for W/D/L later
    var allQuarters: [Quarter] = []
    var quarterMatchMap: [Int: (matchId: Int, awaygoals: Int)] = [:]
    await withTaskGroup(of: [Quarter].self) { group in
        for match in finished {
            group.addTask {
                let resp = try? await APIClient.shared.request(
                    .quarters(matchId: match.id),
                    responseType: ItemsResponse<Quarter>.self
                )
                return resp?.items ?? []
            }
        }
        for await quarters in group {
            allQuarters.append(contentsOf: quarters)
            for q in quarters { quarterMatchMap[q.id] = (matchId: q.match, awaygoals: q.awaygoals) }
        }
    }

    // quarter → record
    var allRecords: [Record] = []
    await withTaskGroup(of: [Record].self) { group in
        for quarter in allQuarters {
            group.addTask {
                let resp = try? await APIClient.shared.request(
                    .records(quarterId: quarter.id),
                    responseType: ItemsResponse<Record>.self
                )
                return resp?.items ?? []
            }
        }
        for await r in group { allRecords.append(contentsOf: r) }
    }

    // player별 집계 + 경기 추적
    var agg: [Int: (goal: Int, assist: Int, min: Int)] = [:]
    var matchHomeGoals: [Int: Int] = [:]
    var playerMatchIds: [Int: Set<Int>] = [:]
    for r in allRecords {
        var s = agg[r.player] ?? (0, 0, 0)
        s.goal += r.goal; s.assist += r.assist; s.min += r.min
        agg[r.player] = s
        if let qInfo = quarterMatchMap[r.quarter] {
            matchHomeGoals[qInfo.matchId, default: 0] += r.goal
            playerMatchIds[r.player, default: []].insert(qInfo.matchId)
        }
    }

    // W/D/L 계산
    var wins = 0, draws = 0, losses = 0
    for match in finished {
        let home = matchHomeGoals[match.id] ?? 0
        let away = allQuarters.filter { $0.match == match.id }.reduce(0) { $0 + $1.awaygoals }
        if home > away { wins += 1 }
        else if home == away { draws += 1 }
        else { losses += 1 }
    }

    let playerStatsList = players.compactMap { p -> PlayerStats? in
        guard let s = agg[p.id], s.goal > 0 || s.assist > 0 || s.min > 0 else { return nil }
        let games = playerMatchIds[p.id]?.count ?? 0
        return PlayerStats(id: p.id, name: p.name, number: p.number, position: p.pos,
                           goal: s.goal, assist: s.assist, min: s.min, games: games)
    }

    var result = TeamStats(
        matchCount: finished.count,
        totalGoal: playerStatsList.reduce(0) { $0 + $1.goal },
        totalAssist: playerStatsList.reduce(0) { $0 + $1.assist },
        players: playerStatsList
    )
    result.wins = wins; result.draws = draws; result.losses = losses
    return result
}
