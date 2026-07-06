import Foundation
import Combine

// 지난 경기 월별 섹션
struct MatchMonthSection: Identifiable {
    let id: String      // "2026-05"
    let title: String   // "2026년 05월"
    let matches: [Match]
}

// 경기 결과 (쿼터·기록 합산). 쿼터가 없는 경기(미진행)는 결과 없음으로 취급
struct MatchScore: Equatable {
    let home: Int
    let away: Int

    var result: String {   // "W"/"D"/"L"
        if home > away { return "W" }
        if home < away { return "L" }
        return "D"
    }

    var resultLabel: String {   // "승"/"무"/"패"
        switch result {
        case "W": return "승"
        case "L": return "패"
        default:  return "무"
        }
    }
}

@MainActor
final class MatchViewModel: ObservableObject {
    @Published var matches: [Match] = []
    @Published var matchScores: [Int: MatchScore] = [:]  // matchId -> 점수·결과
    @Published var isLoading = false
    @Published var errorMessage: String?
    @Published var deletingMatchIds: Set<Int> = []

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
    private var scoreTasks: [Task<Void, Never>] = []   // 백그라운드 점수 로드 — 재로드 시 취소
    private var loadingScoreIds: Set<Int> = []         // in-flight 중복 요청 방지

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
        scoreTasks.forEach { $0.cancel() }   // 이전 로드의 백그라운드 점수 Task 정리
        scoreTasks.removeAll()
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
            fetchScoresInBackground(for: pastMatches)
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
            fetchScoresInBackground(for: newItems)
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
        // 홈 탭에서 결과가 필요한 건 최근 5경기(요약 카드 + 최근 경기 리스트)뿐
        let recent = matches
            .filter { ($0.parsedDate ?? .distantFuture) <= Date() }
            .sorted { ($0.parsedDate ?? .distantPast) > ($1.parsedDate ?? .distantPast) }
            .prefix(5)
        await fetchScores(for: Array(recent))
    }

    // 리스트 표시를 막지 않도록 점수는 뒤에서 채움 (도착하는 대로 행에 반영)
    private func fetchScoresInBackground(for targets: [Match]) {
        scoreTasks.append(Task { await fetchScores(for: targets) })
    }

    private func fetchScores(for targets: [Match]) async {
        let pending = targets.filter { matchScores[$0.id] == nil && !loadingScoreIds.contains($0.id) }
        guard !pending.isEmpty else { return }
        pending.forEach { loadingScoreIds.insert($0.id) }
        defer { pending.forEach { loadingScoreIds.remove($0.id) } }

        await withTaskGroup(of: (Int, MatchScore)?.self) { group in
            for match in pending {
                group.addTask {
                    guard let score = try? await Self.loadScore(for: match) else { return nil }
                    return (match.id, score)
                }
            }
            for await item in group {
                if let (id, score) = item {
                    matchScores[id] = score
                }
            }
        }
    }

    // 쿼터 awaygoals 합 = 실점, 기록 goal 합 = 득점. 쿼터가 없으면 미진행 → nil
    private static func loadScore(for match: Match) async throws -> MatchScore? {
        let qResp = try await APIClient.shared.request(
            .quarters(matchId: match.id),
            responseType: ItemsResponse<Quarter>.self
        )
        let quarters = qResp.items ?? []
        guard !quarters.isEmpty else { return nil }

        var homeGoals = 0
        let awayGoals = quarters.reduce(0) { $0 + $1.awaygoals }

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

        return MatchScore(home: homeGoals, away: awayGoals)
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

    // 목록에서 직접 삭제 (길게 누르기). 성공 시 다른 화면 갱신용 알림도 전파
    func deleteMatch(id: Int) async {
        guard !deletingMatchIds.contains(id) else { return }
        deletingMatchIds.insert(id)
        defer { deletingMatchIds.remove(id) }
        do {
            _ = try await APIClient.shared.request(
                .deleteMatch(id: id),
                responseType: CodeResponse.self
            )
            removeMatch(id: id)
            NotificationCenter.default.post(
                name: .matchDeleted,
                object: nil,
                userInfo: ["matchId": id]
            )
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // 상세 화면에서 삭제된 경기를 목록에서 로컬 제거 (API 호출은 QuarterViewModel.deleteMatch)
    func removeMatch(id: Int) {
        matchScores.removeValue(forKey: id)
        matches.removeAll { $0.id == id }
        upcomingMatches.removeAll { $0.id == id }
        pastMatches.removeAll { $0.id == id }
        rebuildMonthSections()
    }
}
