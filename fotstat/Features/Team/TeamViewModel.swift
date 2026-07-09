import Foundation
import Combine

@MainActor
final class TeamViewModel: LoadableViewModel {
    @Published var teams: [Team] = []

    func fetchTeams() async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }
        await withLoading {
            let resp = try await APIClient.shared.request(
                .teams(userId: userId),
                responseType: ItemsResponse<Team>.self
            )
            self.teams = resp.items ?? []
        }
    }

    func createTeam(name: String) async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }
        await mutate {
            _ = try await APIClient.shared.request(
                .createTeam(userId: userId, name: name),
                responseType: CodeResponse.self
            )
            await self.fetchTeams()
        }
    }

    func updateTeam(id: Int, name: String, duration: Int? = nil) async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }
        await mutate {
            _ = try await APIClient.shared.request(
                .updateTeam(id: id, userId: userId, name: name, duration: duration),
                responseType: CodeResponse.self
            )
            await self.fetchTeams()
        }
    }

    func deleteTeam(id: Int) async {
        await withDeleting(id) {
            _ = try await APIClient.shared.request(
                .deleteTeam(id: id),
                responseType: CodeResponse.self
            )
            self.teams.removeAll { $0.id == id }
        }
    }
}
