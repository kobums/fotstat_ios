import Foundation
import Combine

extension Notification.Name {
    /// 선수 삭제 시 부상 명단·통계 등 다른 탭 화면이 재조회하도록 알림
    static let playerDeleted = Notification.Name("fotstat.playerDeleted")
}

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published var players: [Player] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var deletingPlayerIds: Set<Int> = []

    let team: Team

    init(team: Team) {
        self.team = team
    }

    func fetchPlayers() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let resp = try await APIClient.shared.request(
                .players(teamId: team.id),
                responseType: ItemsResponse<Player>.self
            )
            players = resp.items ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createPlayer(name: String, number: Int?, pos: String? = nil, birthdate: String? = nil) async {
        do {
            _ = try await APIClient.shared.request(
                .createPlayer(teamId: team.id, name: name, number: number ?? 0, position: pos, birthdate: birthdate),
                responseType: CodeResponse.self
            )
            await fetchPlayers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updatePlayer(id: Int, name: String, number: Int?, pos: String? = nil, birthdate: String? = nil) async {
        do {
            _ = try await APIClient.shared.request(
                .updatePlayer(id: id, teamId: team.id, name: name, number: number ?? 0, position: pos, birthdate: birthdate),
                responseType: CodeResponse.self
            )
            await fetchPlayers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deletePlayer(id: Int) async {
        guard !deletingPlayerIds.contains(id) else { return }
        deletingPlayerIds.insert(id)
        defer { deletingPlayerIds.remove(id) }
        do {
            _ = try await APIClient.shared.request(
                .deletePlayer(id: id),
                responseType: CodeResponse.self
            )
            players.removeAll { $0.id == id }
            NotificationCenter.default.post(
                name: .playerDeleted,
                object: nil,
                userInfo: ["playerId": id]
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
