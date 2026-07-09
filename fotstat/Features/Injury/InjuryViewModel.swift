import Foundation
import Combine

extension Notification.Name {
    /// 부상 등록·수정·삭제 시 홈 부상 섹션·통계 등 다른 탭 화면이 재조회하도록 알림
    static let injuryChanged = Notification.Name("fotstat.injuryChanged")
}

@MainActor
final class InjuryViewModel: ObservableObject {
    @Published var injuries: [Injury] = []
    @Published var players: [Player] = []
    @Published var matches: [Match] = []   // 결장 경기 수 계산용 팀 경기 목록
    @Published var isLoading = false
    @Published var errorMessage: String?

    let team: Team

    init(team: Team) {
        self.team = team
    }

    /// 현재 부상 중(복귀 전)인 이력만, 발생일 최신순.
    var activeInjuries: [Injury] {
        injuries
            .filter { $0.isActive }
            .sorted { ($0.startdate ?? "") > ($1.startdate ?? "") }
    }

    /// 복귀가 끝난 지난 부상 이력, 발생일 최신순 (웹 InjuriesPage "지난 부상"과 동일 기준).
    var pastInjuries: [Injury] {
        injuries
            .filter { !$0.isActive }
            .sorted { ($0.startdate ?? "") > ($1.startdate ?? "") }
    }

    /// 현재 부상 중인 선수 id 집합 — 등록 폼에서 "부상 중" 표시용
    var activeInjuredPlayerIds: Set<Int> {
        Set(activeInjuries.map(\.player))
    }

    /// 신규 등록 폼의 기본 선수 — 실수 중복 등록을 줄이기 위해 부상 중이 아닌 첫 선수.
    /// 전원 부상 중이면 첫 선수(의도적 복수 부상 등록은 허용).
    var defaultNewInjuryPlayerId: Int {
        let injured = activeInjuredPlayerIds
        return players.first { !injured.contains($0.id) }?.id ?? players.first?.id ?? 0
    }

    func fetch() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let injuriesReq = APIClient.shared.request(
                .injuries(teamId: team.id),
                responseType: ItemsResponse<Injury>.self
            )
            async let playersReq = APIClient.shared.request(
                .players(teamId: team.id),
                responseType: ItemsResponse<Player>.self
            )
            async let matchesReq = APIClient.shared.request(
                .matches(teamId: team.id),
                responseType: ItemsResponse<Match>.self
            )
            let (iResp, pResp) = try await (injuriesReq, playersReq)
            injuries = iResp.items ?? []
            players = pResp.items ?? []
            // matches는 결장 경기 수 표시에만 쓰므로 실패해도 부상 목록·등록 흐름을 막지 않는다
            if let mResp = try? await matchesReq {
                matches = mResp.items ?? []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func playerName(for playerId: Int) -> String { players.name(for: playerId) }

    func playerNumber(for playerId: Int) -> Int? { players.number(for: playerId) }

    /// 부상 기간에 걸친 팀 경기 수 = 결장 경기. 발생일 당일 경기는 뛴 것으로 보고
    /// 세지 않는다 — 결장 범위는 발생일 다음 날부터 복귀일(복귀 전이면 오늘)까지.
    /// 날짜는 "yyyy-MM-dd" 라 문자열 비교로 대소를 판단한다.
    func absentGames(for injury: Injury, matches: [Match]) -> Int {
        InjuryRules.absentGames(for: injury, matches: matches)
    }

    func save(_ draft: InjuryDraft) async -> Bool {
        do {
            let endpoint: Endpoint
            if let id = draft.id {
                endpoint = .updateInjury(id: id, playerId: draft.playerId, type: draft.type,
                                         startdate: draft.startdate, returndate: draft.returndate, memo: draft.memo)
            } else {
                endpoint = .createInjury(playerId: draft.playerId, type: draft.type,
                                         startdate: draft.startdate, returndate: draft.returndate, memo: draft.memo)
            }
            _ = try await APIClient.shared.request(endpoint, responseType: CodeResponse.self)
            await fetch()
            NotificationCenter.default.post(name: .injuryChanged, object: nil)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// 복귀 처리 — 복귀일을 오늘로 종료 (웹 InjuriesPage.endInjury 와 동일).
    /// 날짜를 바꾸려면 항목을 눌러 수정하면 된다.
    func endInjury(_ injury: Injury) async -> Bool {
        var draft = InjuryDraft.from(injury)
        draft.returndate = Date.todayYMD
        return await save(draft)
    }

    /// 성공 여부 반환 — 실패 시 폼을 닫지 않고 에러를 노출해야 한다.
    func delete(id: Int) async -> Bool {
        do {
            _ = try await APIClient.shared.request(.deleteInjury(id: id), responseType: CodeResponse.self)
            await fetch()
            NotificationCenter.default.post(name: .injuryChanged, object: nil)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

/// 부상 등록/수정 폼 입력값. id 가 nil 이면 신규 등록.
struct InjuryDraft {
    var id: Int? = nil
    var playerId: Int
    var type: String = ""
    var startdate: String
    var returndate: String = ""
    var memo: String = ""

    static func new(playerId: Int, startdate: String) -> InjuryDraft {
        InjuryDraft(playerId: playerId, startdate: startdate)
    }

    static func from(_ injury: Injury) -> InjuryDraft {
        InjuryDraft(
            id: injury.id,
            playerId: injury.player,
            type: injury.type ?? "",
            startdate: (injury.startdate ?? "").dayPrefix,
            returndate: (injury.returndate ?? "").dayPrefix,
            memo: injury.memo ?? ""
        )
    }
}
