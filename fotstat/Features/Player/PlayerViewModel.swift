import Foundation
import Combine

extension Notification.Name {
    /// 선수 삭제 시 부상 명단·통계 등 다른 탭 화면이 재조회하도록 알림
    static let playerDeleted = Notification.Name("fotstat.playerDeleted")
}

@MainActor
final class PlayerViewModel: LoadableViewModel {
    @Published var players: [Player] = []

    let team: Team

    init(team: Team) {
        self.team = team
    }

    func fetchPlayers() async {
        await withLoading {
            let resp = try await APIClient.shared.request(
                .players(teamId: self.team.id),
                responseType: ItemsResponse<Player>.self
            )
            self.players = resp.items ?? []
        }
    }

    func createPlayer(name: String, number: Int?, pos: String? = nil, birthdate: String? = nil) async {
        await mutate {
            _ = try await APIClient.shared.request(
                .createPlayer(teamId: self.team.id, name: name, number: number ?? 0, position: pos, birthdate: birthdate),
                responseType: CodeResponse.self
            )
            await self.fetchPlayers()
        }
    }

    func updatePlayer(id: Int, name: String, number: Int?, pos: String? = nil, birthdate: String? = nil) async {
        await mutate {
            _ = try await APIClient.shared.request(
                .updatePlayer(id: id, teamId: self.team.id, name: name, number: number ?? 0, position: pos, birthdate: birthdate),
                responseType: CodeResponse.self
            )
            await self.fetchPlayers()
        }
    }

    func deletePlayer(id: Int) async {
        await withDeleting(id) {
            _ = try await APIClient.shared.request(
                .deletePlayer(id: id),
                responseType: CodeResponse.self
            )
            self.players.removeAll { $0.id == id }
            NotificationCenter.default.post(
                name: .playerDeleted,
                object: nil,
                userInfo: ["playerId": id]
            )
        }
    }
}
