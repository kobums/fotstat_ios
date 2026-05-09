import Foundation
import Combine

@MainActor
final class TeamViewModel: ObservableObject {
    @Published var teams: [Team] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    func fetchTeams() async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let resp = try await APIClient.shared.request(
                .teams(userId: userId),
                responseType: ItemsResponse<Team>.self
            )
            teams = resp.items ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func createTeam(name: String) async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }
        do {
            _ = try await APIClient.shared.request(
                .createTeam(userId: userId, name: name),
                responseType: CodeResponse.self
            )
            await fetchTeams()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateTeam(id: Int, name: String) async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }
        do {
            _ = try await APIClient.shared.request(
                .updateTeam(id: id, userId: userId, name: name),
                responseType: CodeResponse.self
            )
            await fetchTeams()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteTeam(id: Int) async {
        do {
            _ = try await APIClient.shared.request(
                .deleteTeam(id: id),
                responseType: CodeResponse.self
            )
            teams.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
