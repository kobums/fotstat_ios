import Foundation
import Combine

/// 선수 상세의 기간별 통계 — 서버 집계(GET /player/:id/stats) 한 번으로 요약·스쿼드·
/// 경기별 기록·부상 이력·훈련 참석을 모두 받는다(기본 기간: 올해).
@MainActor
final class PlayerDetailViewModel: ObservableObject {
    @Published var result: PlayerStatsResult?
    @Published var isLoading = false
    @Published var errorMessage: String?
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

    /// 이 선수의 집계(서버가 스쿼드 전원을 0 기록 포함으로 내려준다).
    var playerStat: PlayerStats? { result?.summary }

    /// 순위 모집단 — 스쿼드 전원(기록 없는 선수는 0으로).
    var squad: [PlayerStats] { result?.squad ?? [] }

    var matchLogs: [PlayerMatchLog] { result?.matches ?? [] }

    /// 경기별 기록 카드의 NavigationLink(value: Match) 용 — 서버 경기 라인에서 복원.
    var matches: [Match] {
        matchLogs.map { Match(id: $0.matchId, team: team.id, awayname: $0.opponent, matchdate: $0.matchdate) }
    }

    /// 부상 이력은 기간 필터와 무관하게 전체 — 선수 내력이지 기간 집계가 아니다.
    /// 기간 반영은 결장 타일(absentGames)이 담당한다.
    var injuries: [Injury] { result?.injuries ?? [] }

    var matchCount: Int { result?.matchCount ?? 0 }

    func fetch() async {
        isLoading = true
        defer { isLoading = false }
        do {
            let resp = try await APIClient.shared.request(
                .playerStats(playerId: playerId, start: startDay, end: endDay),
                responseType: ItemResponse<PlayerStatsResult>.self
            )
            if let item = resp.item {
                result = item
            } else {
                errorMessage = "선수 통계를 불러오지 못했습니다."
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// "전체 기간 보기" — 기간에 경기가 없을 때.
    func clearPeriod() {
        startDate = nil
        endDate = nil
    }
}
