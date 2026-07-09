import Foundation
import Combine

// 결장 경기 계산에서 오늘 날짜를 "yyyy-MM-dd" 로 만들 때 재사용.
private let injuryDayFormatter: DateFormatter = {
    let f = DateFormatter()
    f.dateFormat = "yyyy-MM-dd"
    f.locale = Locale(identifier: "en_US_POSIX")
    return f
}()

// 통계·리포트 탭이 공유하는 조회 기간 — TeamContextView가 소유하고 두 탭에 주입한다.
@MainActor
final class StatsPeriod: ObservableObject {
    @Published var startDate: Date? = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))
    @Published var endDate: Date? = Date()

    /// onChange 하나로 시작·종료 변경을 함께 감지하기 위한 키 (초기화 버튼처럼
    /// 두 날짜가 동시에 바뀌어도 재조회는 한 번만).
    var key: String {
        "\(startDate?.timeIntervalSince1970 ?? -1)|\(endDate?.timeIntervalSince1970 ?? -1)"
    }
}

// TeamStatsViewModel – shared by TeamStatsContentView (StatsView.swift)

@MainActor
final class TeamStatsViewModel: ObservableObject {
    @Published var stats: TeamStats?
    /// 직전 동일 길이 기간의 통계 — "이전 기간 대비" 비교 타일용. 기간 미지정이면 nil.
    @Published var prevStats: TeamStats?
    /// 현재 기간 원본 — 선수 상세의 경기별 기록·부상 섹션용.
    @Published var raw: TeamStatsRaw?
    @Published var isLoading = false

    let team: Team

    init(team: Team) {
        self.team = team
    }

    func fetch(start startDate: Date?, end endDate: Date?) async {
        isLoading = true
        defer { isLoading = false }
        if let s = startDate, let e = endDate, let prev = Self.previousRange(start: s, end: e) {
            // 현재 기간도 이전 기간과 같은 일 단위 경계로 맞춘다 (시각이 남은 startDate로 인한 빈틈 방지)
            async let currentRaw = loadStatsRaw(teamId: team.id, from: Calendar.current.startOfDay(for: s), to: e)
            async let previous = loadStats(teamId: team.id, from: prev.start, to: prev.end)
            let cr = await currentRaw
            raw = cr
            stats = cr.map(computeTeamStats)
            prevStats = await previous
        } else {
            // 기간 경계는 항상 일 단위로 정규화 — 리포트 탭(ReportViewModel)과 동일 규칙
            let start = startDate.map { Calendar.current.startOfDay(for: $0) }
            let cr = await loadStatsRaw(teamId: team.id, from: start, to: endDate)
            raw = cr
            stats = cr.map(computeTeamStats)
            prevStats = nil
        }
    }

    /// 현재 기간과 같은 길이로 바로 앞에 붙는 기간 (웹 TeamStatsPage.prevRange 와 동일 로직).
    static func previousRange(start: Date, end: Date) -> (start: Date, end: Date)? {
        let cal = Calendar.current
        let s = cal.startOfDay(for: start)
        let e = cal.startOfDay(for: end)
        guard let days = cal.dateComponents([.day], from: s, to: e).day, days >= 0,
              let prevEnd = cal.date(byAdding: .day, value: -1, to: s),
              let prevStart = cal.date(byAdding: .day, value: -days, to: prevEnd) else { return nil }
        return (prevStart, prevEnd)
    }
}

/// 통계·리포트가 공유하는 원본 데이터 묶음 — 한 번의 fan-out(경기→쿼터→기록)으로
/// 팀 통계 집계와 경기별 쿼터 리포트를 모두 만들 수 있다.
struct TeamStatsRaw {
    let players: [Player]
    /// 기간 내 완료(오늘 이전) 경기
    let finished: [Match]
    let quarters: [Quarter]
    let records: [Record]
    let injuries: [Injury]
}

@MainActor
func loadStatsRaw(teamId: Int, from startDate: Date? = nil, to endDate: Date? = nil) async -> TeamStatsRaw? {
    async let playersReq = APIClient.shared.request(
        .players(teamId: teamId),
        responseType: ItemsResponse<Player>.self
    )
    async let matchesReq = APIClient.shared.request(
        .matches(teamId: teamId),
        responseType: ItemsResponse<Match>.self
    )
    async let injuriesReq = APIClient.shared.request(
        .injuries(teamId: teamId),
        responseType: ItemsResponse<Injury>.self
    )
    guard let (playersResp, matchesResp) = try? await (playersReq, matchesReq) else { return nil }
    let injuries = (try? await injuriesReq)?.items ?? []

    let players = playersResp.items ?? []
    var finished = (matchesResp.items ?? []).filter { ($0.parsedDate ?? .distantFuture) <= Date() }
    if let s = startDate {
        finished = finished.filter { ($0.parsedDate ?? .distantPast) >= s }
    }
    if let e = endDate {
        let endOfDay = Calendar.current.date(bySettingHour: 23, minute: 59, second: 59, of: e) ?? e
        finished = finished.filter { ($0.parsedDate ?? .distantFuture) <= endOfDay }
    }

    // match → quarter
    var allQuarters: [Quarter] = []
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

    return TeamStatsRaw(players: players, finished: finished,
                        quarters: allQuarters, records: allRecords, injuries: injuries)
}

@MainActor
func loadStats(teamId: Int, from startDate: Date? = nil, to endDate: Date? = nil) async -> TeamStats? {
    guard let raw = await loadStatsRaw(teamId: teamId, from: startDate, to: endDate) else { return nil }
    return computeTeamStats(raw)
}

@MainActor
func computeTeamStats(_ raw: TeamStatsRaw) -> TeamStats {
    let players = raw.players
    let finished = raw.finished
    let allQuarters = raw.quarters
    let allRecords = raw.records
    let injuries = raw.injuries
    var quarterMatchMap: [Int: (matchId: Int, awaygoals: Int)] = [:]
    for q in allQuarters { quarterMatchMap[q.id] = (matchId: q.match, awaygoals: q.awaygoals) }

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

    // W/D/L·실점 계산
    var wins = 0, draws = 0, losses = 0, conceded = 0
    for match in finished {
        let home = matchHomeGoals[match.id] ?? 0
        let away = allQuarters.filter { $0.match == match.id }.reduce(0) { $0 + $1.awaygoals }
        conceded += away
        if home > away { wins += 1 }
        else if home == away { draws += 1 }
        else { losses += 1 }
    }

    // 선수별 부상 기간 목록 (결장 경기 계산용). 날짜는 "yyyy-MM-dd" 문자열 비교.
    let todayStr = injuryDayFormatter.string(from: Date())
    var injuryPeriods: [Int: [(start: String, end: String)]] = [:]
    for injury in injuries {
        let start = String((injury.startdate ?? "").prefix(10))
        guard !start.isEmpty else { continue }
        let end = injury.isActive ? todayStr : String((injury.returndate ?? "").prefix(10))
        guard !end.isEmpty else { continue }
        injuryPeriods[injury.player, default: []].append((start, end))
    }
    // 통계 기간(finished)에 걸친 결장 경기 수
    func absentGames(for playerId: Int) -> Int {
        guard let periods = injuryPeriods[playerId] else { return 0 }
        return finished.filter { match in
            let day = String(match.matchdate.prefix(10))
            guard !day.isEmpty else { return false }
            // 발생일 당일 경기는 뛴 것으로 보고 결장에서 제외 (start < day)
            return periods.contains { $0.start < day && day <= $0.end }
        }.count
    }

    let playerStatsList = players.compactMap { p -> PlayerStats? in
        let absent = absentGames(for: p.id)
        guard let s = agg[p.id], s.goal > 0 || s.assist > 0 || s.min > 0 else {
            // 기록은 없지만 부상 결장이 있으면 통계에 노출(결장만 표기)
            if absent > 0 {
                return PlayerStats(id: p.id, name: p.name, number: p.number, position: p.pos,
                                   goal: 0, assist: 0, min: 0, games: 0, absentGames: absent)
            }
            return nil
        }
        let games = playerMatchIds[p.id]?.count ?? 0
        return PlayerStats(id: p.id, name: p.name, number: p.number, position: p.pos,
                           goal: s.goal, assist: s.assist, min: s.min, games: games, absentGames: absent)
    }

    var result = TeamStats(
        matchCount: finished.count,
        totalGoal: playerStatsList.reduce(0) { $0 + $1.goal },
        totalAssist: playerStatsList.reduce(0) { $0 + $1.assist },
        players: playerStatsList
    )
    result.wins = wins; result.draws = draws; result.losses = losses
    result.totalConceded = conceded
    return result
}

// MARK: - 선수 상세: 경기별 기록

/// 선수가 뛴 경기 하나의 기록 — 쿼터별(출전분/골/도움/카드)과 경기 합계·스코어.
struct PlayerMatchLog: Identifiable {
    struct QuarterLine: Identifiable {
        let id: Int       // quarter id
        let number: Int
        let min: Int
        let goal: Int
        let assist: Int
        let yellow: Int
        let red: Int
    }
    let matchId: Int
    let opponent: String
    let matchdate: String
    let home: Int         // 우리 팀 득점(경기 내 전 선수 골 합)
    let away: Int         // 상대 득점(쿼터 awaygoals 합)
    let quarters: [QuarterLine]
    let min: Int
    let goal: Int
    let assist: Int
    let yellow: Int
    let red: Int
    var id: Int { matchId }
    var result: String { home > away ? "W" : (home < away ? "L" : "D") }
    var resultLabel: String { home > away ? "승" : (home < away ? "패" : "무") }
}

/// 선수가 기록을 남긴 경기들의 경기별 로그(최신순). 웹 playerMatchLog.ts 미러.
func playerMatchLogs(_ raw: TeamStatsRaw, playerId: Int) -> [PlayerMatchLog] {
    let matchById = Dictionary(raw.finished.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })
    let quarterById = Dictionary(raw.quarters.map { ($0.id, $0) }, uniquingKeysWith: { a, _ in a })

    var awayByMatch: [Int: Int] = [:]
    for q in raw.quarters { awayByMatch[q.match, default: 0] += q.awaygoals }
    var homeByMatch: [Int: Int] = [:]
    for r in raw.records {
        if let q = quarterById[r.quarter] { homeByMatch[q.match, default: 0] += r.goal }
    }

    var linesByMatch: [Int: [PlayerMatchLog.QuarterLine]] = [:]
    for r in raw.records where r.player == playerId {
        guard let q = quarterById[r.quarter] else { continue }
        linesByMatch[q.match, default: []].append(
            .init(id: q.id, number: q.number, min: r.min, goal: r.goal,
                  assist: r.assist, yellow: r.yellowcard, red: r.redcard)
        )
    }

    var logs: [PlayerMatchLog] = []
    for (matchId, rawLines) in linesByMatch {
        guard let m = matchById[matchId] else { continue }
        let lines = rawLines.sorted { $0.number < $1.number }
        logs.append(PlayerMatchLog(
            matchId: matchId, opponent: m.awayname, matchdate: m.matchdate,
            home: homeByMatch[matchId] ?? 0, away: awayByMatch[matchId] ?? 0,
            quarters: lines,
            min: lines.reduce(0) { $0 + $1.min },
            goal: lines.reduce(0) { $0 + $1.goal },
            assist: lines.reduce(0) { $0 + $1.assist },
            yellow: lines.reduce(0) { $0 + $1.yellow },
            red: lines.reduce(0) { $0 + $1.red }
        ))
    }
    return logs.sorted { $0.matchdate > $1.matchdate }
}

/// 선수의 부상 이력(최신 발생순).
func playerInjuries(_ raw: TeamStatsRaw, playerId: Int) -> [Injury] {
    raw.injuries
        .filter { $0.player == playerId }
        .sorted { ($0.startdate ?? "") > ($1.startdate ?? "") }
}
