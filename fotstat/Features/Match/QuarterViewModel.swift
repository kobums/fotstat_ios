import Foundation
import Combine

extension Notification.Name {
    /// 경기 상세 화면에서 경기가 삭제되면 목록 화면이 로컬 반영하도록 알림
    static let matchDeleted = Notification.Name("fotstat.matchDeleted")
}

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

    /// 경기 삭제. 성공 시 목록 갱신용 알림을 보내고 true 반환.
    func deleteMatch() async -> Bool {
        do {
            _ = try await APIClient.shared.request(
                .deleteMatch(id: match.id),
                responseType: CodeResponse.self
            )
            NotificationCenter.default.post(
                name: .matchDeleted,
                object: nil,
                userInfo: ["matchId": match.id]
            )
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
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
