import Foundation
import Combine

@MainActor
final class RecordViewModel: ObservableObject {
    @Published var records: [Record] = []
    @Published var players: [Player] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    let quarter: Quarter
    let team: Team
    private var creatingPlayerIds: Set<Int> = []

    init(quarter: Quarter, team: Team) {
        self.quarter = quarter
        self.team = team
    }

    func fetch() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let recordsReq = APIClient.shared.request(
                .records(quarterId: quarter.id),
                responseType: ItemsResponse<Record>.self
            )
            async let playersReq = APIClient.shared.request(
                .players(teamId: team.id),
                responseType: ItemsResponse<Player>.self
            )
            let (rResp, pResp) = try await (recordsReq, playersReq)
            records = rResp.items ?? []
            players = pResp.items ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createRecord(playerId: Int, min: Int, goal: Int, assist: Int) async {
        guard !creatingPlayerIds.contains(playerId) else { return }
        creatingPlayerIds.insert(playerId)
        defer { creatingPlayerIds.remove(playerId) }
        do {
            _ = try await APIClient.shared.request(
                .createRecord(quarterId: quarter.id, playerId: playerId, min: min, goal: goal, assist: assist),
                responseType: CodeResponse.self
            )
            await fetchRecords()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateRecord(id: Int, min: Int, goal: Int, assist: Int) async {
        let playerId = records.first(where: { $0.id == id })?.player ?? 0
        do {
            _ = try await APIClient.shared.request(
                .updateRecord(id: id, quarterId: quarter.id, playerId: playerId, min: min, goal: goal, assist: assist),
                responseType: CodeResponse.self
            )
            await fetchRecords()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func fetchRecords() async {
        do {
            let resp = try await APIClient.shared.request(
                .records(quarterId: quarter.id),
                responseType: ItemsResponse<Record>.self
            )
            records = resp.items ?? []
        } catch {}
    }

    func deleteRecord(id: Int) async {
        do {
            _ = try await APIClient.shared.request(
                .deleteRecord(id: id),
                responseType: CodeResponse.self
            )
            records.removeAll { $0.id == id }
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
}
