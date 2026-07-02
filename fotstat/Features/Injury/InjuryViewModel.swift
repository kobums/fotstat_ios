import Foundation
import Combine

@MainActor
final class InjuryViewModel: ObservableObject {
    @Published var injuries: [Injury] = []
    @Published var players: [Player] = []
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
            let (iResp, pResp) = try await (injuriesReq, playersReq)
            injuries = iResp.items ?? []
            players = pResp.items ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func playerName(for playerId: Int) -> String {
        players.first(where: { $0.id == playerId })?.name ?? "알 수 없음"
    }

    func playerNumber(for playerId: Int) -> Int? {
        players.first(where: { $0.id == playerId })?.number
    }

    /// 부상 기간(startdate ~ returndate, 복귀 전이면 오늘까지)에 걸친 팀 경기 수 = 결장 경기.
    /// 날짜는 "yyyy-MM-dd" 라 문자열 비교로 대소를 판단한다.
    func absentGames(for injury: Injury, matches: [Match]) -> Int {
        let start = String((injury.startdate ?? "").prefix(10))
        guard !start.isEmpty else { return 0 }
        let end = injury.isActive ? Self.today() : String((injury.returndate ?? "").prefix(10))
        guard !end.isEmpty else { return 0 }

        return matches.filter { match in
            let day = String(match.matchdate.prefix(10))
            return !day.isEmpty && start <= day && day <= end
        }.count
    }

    private static func today() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
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
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// 성공 여부 반환 — 실패 시 폼을 닫지 않고 에러를 노출해야 한다.
    func delete(id: Int) async -> Bool {
        do {
            _ = try await APIClient.shared.request(.deleteInjury(id: id), responseType: CodeResponse.self)
            await fetch()
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

    static func new(playerId: Int, today: String) -> InjuryDraft {
        InjuryDraft(playerId: playerId, startdate: today)
    }

    static func from(_ injury: Injury) -> InjuryDraft {
        InjuryDraft(
            id: injury.id,
            playerId: injury.player,
            type: injury.type ?? "",
            startdate: String((injury.startdate ?? "").prefix(10)),
            returndate: String((injury.returndate ?? "").prefix(10)),
            memo: injury.memo ?? ""
        )
    }
}
