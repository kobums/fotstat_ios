import Foundation
import Combine

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published var players: [Player] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

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

    func createPlayer(name: String, number: Int?, pos: String? = nil) async {
        do {
            _ = try await APIClient.shared.request(
                .createPlayer(teamId: team.id, name: name, number: number ?? 0, position: pos),
                responseType: CodeResponse.self
            )
            await fetchPlayers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updatePlayer(id: Int, name: String, number: Int?, pos: String? = nil) async {
        do {
            _ = try await APIClient.shared.request(
                .updatePlayer(id: id, teamId: team.id, name: name, number: number ?? 0, position: pos),
                responseType: CodeResponse.self
            )
            await fetchPlayers()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deletePlayer(id: Int) async {
        do {
            _ = try await APIClient.shared.request(
                .deletePlayer(id: id),
                responseType: CodeResponse.self
            )
            players.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
