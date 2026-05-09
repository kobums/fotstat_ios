import Foundation
import Combine

struct QuarterSummary: Identifiable {
    let quarter: Quarter
    let homeGoals: Int
    let maxMinutes: Int
    var awayGoals: Int
    var id: Int { quarter.id }
}

@MainActor
final class QuarterViewModel: ObservableObject {
    @Published var summaries: [QuarterSummary] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    let match: Match

    var quarters: [Quarter] { summaries.map(\.quarter) }

    init(match: Match) {
        self.match = match
    }

    func fetchQuarters() async {
        isLoading = true
        defer { isLoading = false }

        do {
            let resp = try await APIClient.shared.request(
                .quarters(matchId: match.id),
                responseType: ItemsResponse<Quarter>.self
            )
            let fetched = resp.items ?? []
            summaries = await loadSummaries(for: fetched)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func loadSummaries(for quarters: [Quarter]) async -> [QuarterSummary] {
        var result: [QuarterSummary] = []
        for q in quarters {
            do {
                let resp = try await APIClient.shared.request(
                    .records(quarterId: q.id),
                    responseType: ItemsResponse<Record>.self
                )
                let records = resp.items ?? []
                result.append(QuarterSummary(
                    quarter: q,
                    homeGoals: records.reduce(0) { $0 + $1.goal },
                    maxMinutes: records.map(\.min).max() ?? 0,
                    awayGoals: q.awaygoals
                ))
            } catch {
                result.append(QuarterSummary(quarter: q, homeGoals: 0, maxMinutes: 0, awayGoals: q.awaygoals))
            }
        }
        return result
    }

    func addNextQuarter(duration: Int) async {
        let nextNumber = (quarters.map(\.number).max() ?? 0) + 1
        do {
            _ = try await APIClient.shared.request(
                .createQuarter(matchId: match.id, number: nextNumber, duration: duration),
                responseType: CodeResponse.self
            )
            await fetchQuarters()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func updateAwayGoals(quarterId: Int, awaygoals: Int) async {
        // 로컬 즉시 반영
        if let idx = summaries.firstIndex(where: { $0.id == quarterId }) {
            summaries[idx].awayGoals = awaygoals
        }
        do {
            _ = try await APIClient.shared.request(
                .updateQuarterAwayGoals(id: quarterId, awaygoals: awaygoals),
                responseType: CodeResponse.self
            )
        } catch {
            // 실패 시 서버 값으로 복원
            await fetchQuarters()
            errorMessage = error.localizedDescription
        }
    }

    func deleteQuarter(id: Int) async {
        do {
            _ = try await APIClient.shared.request(
                .deleteQuarter(id: id),
                responseType: CodeResponse.self
            )
            summaries.removeAll { $0.id == id }
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
