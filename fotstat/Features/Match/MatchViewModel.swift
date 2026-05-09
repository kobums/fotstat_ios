import Foundation
import Combine

@MainActor
final class MatchViewModel: ObservableObject {
    @Published var matches: [Match] = []
    @Published var matchResults: [Int: String] = [:]  // matchId -> "W"/"D"/"L"
    @Published var isLoading = false
    @Published var errorMessage: String?

    let team: Team

    init(team: Team) {
        self.team = team
    }

    func fetchMatches() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let resp = try await APIClient.shared.request(
                .matches(teamId: team.id),
                responseType: ItemsResponse<Match>.self
            )
            matches = resp.items ?? []
        } catch {
            errorMessage = error.localizedDescription
        }
        await fetchRecentResults()
    }

    private func fetchRecentResults() async {
        let recent = matches
            .filter { ($0.parsedDate ?? .distantFuture) <= Date() }
            .sorted { ($0.parsedDate ?? .distantPast) > ($1.parsedDate ?? .distantPast) }
            .prefix(5)

        var results: [Int: String] = [:]
        await withTaskGroup(of: (Int, String)?.self) { group in
            for match in recent {
                group.addTask {
                    guard let result = try? await self.loadResult(for: match) else { return nil }
                    return (match.id, result)
                }
            }
            for await item in group {
                if let (id, result) = item {
                    results[id] = result
                }
            }
        }
        matchResults = results
    }

    private func loadResult(for match: Match) async throws -> String {
        let qResp = try await APIClient.shared.request(
            .quarters(matchId: match.id),
            responseType: ItemsResponse<Quarter>.self
        )
        let quarters = qResp.items ?? []

        var homeGoals = 0
        var awayGoals = quarters.reduce(0) { $0 + $1.awaygoals }

        await withTaskGroup(of: Int.self) { group in
            for q in quarters {
                group.addTask {
                    let rResp = try? await APIClient.shared.request(
                        .records(quarterId: q.id),
                        responseType: ItemsResponse<Record>.self
                    )
                    return rResp?.items?.reduce(0) { $0 + $1.goal } ?? 0
                }
            }
            for await goals in group { homeGoals += goals }
        }

        if homeGoals > awayGoals { return "W" }
        if homeGoals < awayGoals { return "L" }
        return "D"
    }

    func createMatch(awayName: String, matchDate: Date) async {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        let dateStr = f.string(from: matchDate)

        do {
            _ = try await APIClient.shared.request(
                .createMatch(teamId: team.id, awayname: awayName, matchdate: dateStr),
                responseType: CodeResponse.self
            )
            await fetchMatches()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func deleteMatch(id: Int) async {
        do {
            _ = try await APIClient.shared.request(
                .deleteMatch(id: id),
                responseType: CodeResponse.self
            )
            matches.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
