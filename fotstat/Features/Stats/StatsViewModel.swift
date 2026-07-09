import Foundation
import Combine

@MainActor
final class StatsViewModel: ObservableObject {
    @Published var teams: [Team] = []
    @Published var teamStats: TeamStats?
    /// 현재 기간 원본 — 선수 상세의 경기별 기록·부상 섹션용.
    @Published var raw: TeamStatsRaw?
    @Published var isLoading = false
    @Published var isLoadingStats = false
    @Published var startDate: Date? = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))
    @Published var endDate: Date? = Date()
    @Published var selectedTeamId: Int? = nil {
        didSet { Task { await fetchStats() } }
    }

    func fetchTeams() async {
        guard let userId = AuthManager.shared.currentUser?.id else { return }
        isLoading = true
        defer { isLoading = false }

        do {
            let resp = try await APIClient.shared.request(
                .teams(userId: userId),
                responseType: ItemsResponse<Team>.self
            )
            teams = resp.items ?? []
            if selectedTeamId == nil {
                selectedTeamId = teams.first?.id
            }
        } catch {}
    }

    func fetchStats() async {
        guard let teamId = selectedTeamId else { return }
        isLoadingStats = true
        defer { isLoadingStats = false }
        let cr = await loadStatsRaw(teamId: teamId, from: startDate, to: endDate)
        raw = cr
        teamStats = cr.map(computeTeamStats)
    }
}
