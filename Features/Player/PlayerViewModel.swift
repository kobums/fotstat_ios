import Foundation
import Combine

struct PlayerStat {
    let games: Int
    let goals: Int
    let assists: Int
    let minutes: Int
}

@MainActor
final class PlayerViewModel: ObservableObject {
    @Published var players: [Player] = []
    @Published var stats: [Int: PlayerStat] = [:]
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
        await fetchStats()
    }

    private func fetchStats() async {
        var newStats: [Int: PlayerStat] = [:]
        await withTaskGroup(of: (Int, PlayerStat).self) { group in
            for player in players {
                group.addTask {
                    let resp = try? await APIClient.shared.request(
                        .recordsByPlayer(playerId: player.id),
                        responseType: ItemsResponse<Record>.self
                    )
                    let records = resp?.items ?? []
                    return (player.id, PlayerStat(
                        games: records.filter { $0.min > 0 }.count,
                        goals: records.reduce(0) { $0 + $1.goal },
                        assists: records.reduce(0) { $0 + $1.assist },
                        minutes: records.reduce(0) { $0 + $1.min }
                    ))
                }
            }
            for await (id, stat) in group {
                newStats[id] = stat
            }
        }
        stats = newStats
    }

    func createPlayer(name: String, number: Int?, pos: String? = nil) async {
        do {
            _ = try await APIClient.shared.request(
                .createPlayer(teamId: team.id, name: name, number: number ?? 0),
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
                .updatePlayer(id: id, teamId: team.id, name: name, number: number ?? 0),
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
