import Foundation
import Combine

/// 선수 상세의 기간별 통계 — 팀 통계와 같은 fan-out(loadStatsRaw)을 선수 상세 기간
/// (기본: 올해)으로 돌린다. 백엔드 선수 통계 API가 없어 클라이언트 집계.
@MainActor
final class PlayerDetailViewModel: ObservableObject {
    @Published var raw: TeamStatsRaw?
    @Published var stats: TeamStats?
    @Published var isLoading = false
    /// 기본 집계 기간 = 올해(1월 1일 ~ 오늘). 통계 탭의 "이번 달"과 달리 한 선수를 길게 본다.
    @Published var startDate: Date? = DateRangeFilter.yearStart
    @Published var endDate: Date? = Date()

    let team: Team
    let playerId: Int

    init(team: Team, playerId: Int) {
        self.team = team
        self.playerId = playerId
    }

    /// onChange 하나로 시작·종료 변경을 함께 감지하기 위한 키.
    var periodKey: String {
        "\(startDate?.timeIntervalSince1970 ?? -1)|\(endDate?.timeIntervalSince1970 ?? -1)"
    }

    /// 기간 경계를 "yyyy-MM-dd"로 — 훈련 참석률을 경기 집계와 같은 기간으로 자를 때 쓴다.
    var startDay: String? { startDate.map { DateFormats.day.string(from: $0) } }
    var endDay: String? { endDate.map { DateFormats.day.string(from: $0) } }

    /// 기간이 지정돼 있는가(전체 기간 보기가 아닌가).
    var isRanged: Bool { startDate != nil || endDate != nil }

    /// 이 선수의 집계. computeTeamStats는 기록 없는 선수를 제외하므로 없으면 0 기록.
    var playerStat: PlayerStats? {
        stats?.players.first { $0.id == playerId }
    }

    /// 순위 모집단 — 스쿼드 전원(기록 없는 선수는 0으로).
    var squad: [PlayerStats] {
        guard let raw, let stats else { return [] }
        return PlayerRank.fullSquad(players: raw.players, stats: stats.players)
    }

    var matchLogs: [PlayerMatchLog] {
        raw.map { playerMatchLogs($0, playerId: playerId) } ?? []
    }

    /// 부상 이력은 기간 필터와 무관하게 전체 — 선수 내력이지 기간 집계가 아니다.
    /// 기간 반영은 결장 타일(absentGames)이 담당한다.
    var injuries: [Injury] {
        raw.map { playerInjuries($0, playerId: playerId) } ?? []
    }

    func fetch() async {
        isLoading = true
        defer { isLoading = false }
        let start = startDate.map { Calendar.current.startOfDay(for: $0) }
        let cr = await loadStatsRaw(teamId: team.id, from: start, to: endDate)
        raw = cr
        stats = cr.map(computeTeamStats)
    }

    /// "전체 기간 보기" — 기간에 경기가 없을 때.
    func clearPeriod() {
        startDate = nil
        endDate = nil
    }
}
