import Foundation
import Combine

// 지난 경기 월별 섹션
struct MatchMonthSection: Identifiable {
    let id: String      // "2026-05"
    let title: String   // "2026년 05월"
    let matches: [Match]
}

@MainActor
final class MatchViewModel: ObservableObject {
    @Published var matches: [Match] = []
    @Published var matchResults: [Int: String] = [:]  // matchId -> "W"/"D"/"L"
    @Published var isLoading = false
    @Published var errorMessage: String?

    // 경기 리스트 화면용 — 예정 고정 + 지난 경기 페이지네이션
    @Published var upcomingMatches: [Match] = []
    @Published var pastMatches: [Match] = []
    @Published private(set) var monthSections: [MatchMonthSection] = []   // pastMatches 변경 시에만 재계산
    @Published var isLoadingMore = false
    @Published var pastLoadFailed = false       // 추가 로드 실패 → 자동 재시도 대신 수동 재시도
    private var pastPage = 0
    private var pastReachedEnd = false          // 마지막 페이지 도달(또는 초기 실패)
    private var pastCutoff = ""                 // loadInitial 시점 고정 — 모든 페이지가 동일 기준 사용
    private let pageSize = 20
    private let calendar = Calendar.current

    var hasMorePast: Bool { !pastReachedEnd }

    let team: Team

    init(team: Team) {
        self.team = team
    }

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    // 진입/갱신 시 호출: 예정 전체 + 지난 1페이지
    func loadInitial() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        pastPage = 0
        pastReachedEnd = false
        pastLoadFailed = false
        pastMatches = []
        monthSections = []
        pastCutoff = Self.dateFormatter.string(from: Date())   // 페이지네이션 기준 시각 고정

        async let upcomingReq = APIClient.shared.request(
            .matchesUpcoming(teamId: team.id, after: pastCutoff),
            responseType: ItemsResponse<Match>.self
        )
        async let pastReq = APIClient.shared.request(
            .matchesPast(teamId: team.id, before: pastCutoff, page: 1, pagesize: pageSize),
            responseType: ItemsResponse<Match>.self
        )
        do {
            let (uResp, pResp) = try await (upcomingReq, pastReq)
            upcomingMatches = uResp.items ?? []
            let pItems = pResp.items ?? []
            // 경계(now) 중복 방지: 예정 목록에 있는 경기는 지난 목록에서 제외
            let upcomingIds = Set(upcomingMatches.map { $0.id })
            pastMatches = pItems.filter { !upcomingIds.contains($0.id) }
            rebuildMonthSections()
            pastPage = 1
            // 종료 판정: 받은 페이지가 pageSize 미만이거나 total 도달
            pastReachedEnd = pItems.count < pageSize || (pResp.total.map { pastMatches.count >= $0 } ?? false)
        } catch {
            errorMessage = error.localizedDescription
            pastReachedEnd = true   // 초기 로드 실패 시 무한 트리거 방지(에러 alert로 안내)
        }
    }

    // 무한 스크롤: 다음 페이지 append
    func loadMorePast() async {
        guard !isLoadingMore, hasMorePast else { return }
        isLoadingMore = true
        pastLoadFailed = false
        defer { isLoadingMore = false }

        let nextPage = pastPage + 1
        do {
            let resp = try await APIClient.shared.request(
                .matchesPast(teamId: team.id, before: pastCutoff, page: nextPage, pagesize: pageSize),
                responseType: ItemsResponse<Match>.self
            )
            let items = resp.items ?? []
            let newItems = items.filter { m in !pastMatches.contains(where: { $0.id == m.id }) }
            pastMatches.append(contentsOf: newItems)
            rebuildMonthSections()
            pastPage = nextPage
            if items.count < pageSize { pastReachedEnd = true }
        } catch {
            errorMessage = error.localizedDescription
            pastLoadFailed = true   // 자동 재시도 루프 방지 — 사용자가 수동 재시도
        }
    }

    // 지난 경기 → 월별 섹션 재계산 (pastMatches 변경 시에만 호출). 서버가 이미 matchdate desc 정렬, 등장 순서 보존
    private func rebuildMonthSections() {
        var order: [String] = []
        var map: [String: [Match]] = [:]
        for m in pastMatches {
            guard let d = m.parsedDate else { continue }
            let c = calendar.dateComponents([.year, .month], from: d)
            let key = String(format: "%04d-%02d", c.year ?? 0, c.month ?? 0)
            if map[key] == nil { map[key] = []; order.append(key) }
            map[key]?.append(m)
        }
        monthSections = order.map { key in
            let p = key.split(separator: "-")
            return MatchMonthSection(id: key, title: "\(p[0])년 \(p[1])월", matches: map[key] ?? [])
        }
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
        let dateStr = Self.dateFormatter.string(from: matchDate)

        do {
            _ = try await APIClient.shared.request(
                .createMatch(teamId: team.id, awayname: awayName, matchdate: dateStr),
                responseType: CodeResponse.self
            )
            await loadInitial()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // 상세 화면에서 삭제된 경기를 목록에서 로컬 제거 (API 호출은 QuarterViewModel.deleteMatch)
    func removeMatch(id: Int) {
        matches.removeAll { $0.id == id }
        upcomingMatches.removeAll { $0.id == id }
        pastMatches.removeAll { $0.id == id }
        rebuildMonthSections()
    }
}
