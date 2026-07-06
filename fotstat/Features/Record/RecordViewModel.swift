import Foundation
import Combine

@MainActor
final class RecordViewModel: ObservableObject {
    // 선수별 입력값 — 화면 합계/카운트의 단일 진실 원천
    struct Draft: Equatable {
        var min: Int
        var goal: Int
        var assist: Int
        var yellowcard: Int
        var redcard: Int
    }

    @Published var records: [Record] = []
    @Published var players: [Player] = []
    @Published var drafts: [Int: Draft] = [:]   // playerId -> 입력값
    @Published var injuredPlayerIds: Set<Int> = []  // 이 경기일에 부상 중인 선수 — 입력 차단
    @Published var isLoading = false
    @Published var errorMessage: String?

    let quarter: Quarter
    let team: Team
    let match: Match
    private var savingPlayerIds: Set<Int> = []        // 저장 루프 중복 진입 방지
    private var createdPlayerIds: Set<Int> = []       // 이미 create 한 선수 — 중복 생성 방지
    private var saveTasks: [Int: Task<Void, Never>] = [:]
    private var pendingSaveIds: Set<Int> = []         // 디바운스 대기 중(아직 전송 전)인 선수

    init(quarter: Quarter, team: Team, match: Match) {
        self.quarter = quarter
        self.team = team
        self.match = match
    }

    func isInjured(_ playerId: Int) -> Bool {
        injuredPlayerIds.contains(playerId)
    }

    // 화면 표시값은 모두 drafts(사용자 입력)에서 계산 → 입력과 항상 일치
    var totalGoals: Int { drafts.values.reduce(0) { $0 + $1.goal } }
    var totalAssists: Int { drafts.values.reduce(0) { $0 + $1.assist } }
    var playedCount: Int { drafts.values.filter { $0.min > 0 }.count }   // 0분 제외 = 실제 출전 인원

    func draft(for playerId: Int) -> Draft {
        drafts[playerId] ?? Draft(min: 0, goal: 0, assist: 0, yellowcard: 0, redcard: 0)
    }

    func fetch() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let recordsReq = APIClient.shared.request(
                .records(quarterId: quarter.id),
                responseType: ItemsResponse<Record>.self
            )
            async let playersReq = APIClient.shared.request(
                .players(teamId: team.id),
                responseType: ItemsResponse<Player>.self
            )
            async let injuriesReq = APIClient.shared.request(
                .injuries(teamId: team.id),
                responseType: ItemsResponse<Injury>.self
            )
            let (rResp, pResp, iResp) = try await (recordsReq, playersReq, injuriesReq)
            records = rResp.items ?? []
            players = pResp.items ?? []
            injuredPlayerIds = Self.injuredPlayers(injuries: iResp.items ?? [], on: match.matchdate)
            rebuildDrafts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // 부상 목록만 재조회해 입력 차단 상태를 갱신한다. 이 화면에서 부상을 등록한 직후
    // 즉시 반영용 — fetch()와 달리 drafts를 건드리지 않아 디바운스 대기 중 입력이 유실되지 않는다.
    func refreshInjuries() async {
        do {
            let resp = try await APIClient.shared.request(
                .injuries(teamId: team.id),
                responseType: ItemsResponse<Injury>.self
            )
            injuredPlayerIds = Self.injuredPlayers(injuries: resp.items ?? [], on: match.matchdate)
        } catch {
            if !Self.isCancellation(error) { errorMessage = error.localizedDescription }
        }
    }

    // 경기일이 부상 기간에 걸치는 선수 id 집합. 발생일 당일 경기는 제외한다
    // (경기 중 부상 = 그날까지는 뛴 것) — 차단 범위는 발생일 다음 날부터 복귀일까지,
    // returndate 비면 아직 부상 중. 백엔드 injuryConflict와 동일 규칙.
    // 날짜는 "yyyy-MM-dd" 형태라 문자열 비교로 대소를 판단할 수 있다.
    static func injuredPlayers(injuries: [Injury], on matchdate: String) -> Set<Int> {
        let day = String(matchdate.prefix(10))
        guard !day.isEmpty else { return [] }
        var ids: Set<Int> = []
        for injury in injuries {
            let start = String((injury.startdate ?? "").prefix(10))
            guard !start.isEmpty, start < day else { continue }
            let end = String((injury.returndate ?? "").prefix(10))
            if end.isEmpty || day <= end {
                ids.insert(injury.player)
            }
        }
        return ids
    }

    // 서버 records를 drafts에 반영. playerId 기준이라 서버에 같은 선수 record가 중복돼도 마지막 것만 집계(방어)
    private func rebuildDrafts() {
        var next: [Int: Draft] = [:]
        for r in records {
            next[r.player] = Draft(min: r.min, goal: r.goal, assist: r.assist, yellowcard: r.yellowcard, redcard: r.redcard)
        }
        drafts = next
    }

    // 어시스트 불변식 — ① 자기 골에는 어시스트 불가(개인 assist ≤ 남의 골 합)
    //                  ② 팀 assist 합 ≤ 팀 goal 합
    // 이 선수가 가질 수 있는 최대 어시스트. UI(+버튼 비활성)와 updateDraft(값 클램프) 양쪽에서 사용
    func assistCap(for playerId: Int) -> Int {
        let d = draft(for: playerId)
        let othersGoals = totalGoals - d.goal
        let othersAssists = totalAssists - d.assist
        return Swift.max(0, Swift.min(othersGoals, totalGoals - othersAssists))
    }

    // 카드 값이 바뀔 때마다 즉시 호출 → draft 갱신(합계 즉시 반영) 후 네트워크 저장은 디바운스
    func updateDraft(playerId: Int, min: Int, goal: Int, assist: Int, yellowcard: Int, redcard: Int) {
        // 부상 중인 선수는 입력을 저장하지 않는다(백엔드도 거부하지만 UI 차원에서 선차단)
        guard !injuredPlayerIds.contains(playerId) else { return }
        // 어시스트 불변식 검증 — UI 캡과 별개로 값 자체를 클램프(이중 방어)
        let othersGoals = drafts.reduce(0) { $0 + ($1.key == playerId ? 0 : $1.value.goal) }
        let othersAssists = drafts.reduce(0) { $0 + ($1.key == playerId ? 0 : $1.value.assist) }
        let cap = Swift.max(0, Swift.min(othersGoals, othersGoals + goal - othersAssists))
        let goalChanged = drafts[playerId]?.goal != goal
        drafts[playerId] = Draft(min: min, goal: goal, assist: Swift.min(assist, cap), yellowcard: yellowcard, redcard: redcard)
        if goalChanged { rebalanceAssists() }   // 골 감소로 다른 선수의 어시스트가 초과되면 함께 차감
        scheduleSave(playerId)
    }

    // 골 변경으로 무너진 어시스트 불변식 복구. 초과분은 명단 아래쪽 선수부터 차감.
    // 부상 선수는 입력이 차단된 상태라 기록을 건드리지 않는다(저장도 백엔드가 거부)
    private func rebalanceAssists() {
        let totalG = totalGoals
        for (pid, d) in drafts where !injuredPlayerIds.contains(pid) {
            let cap = Swift.max(0, totalG - d.goal)
            if d.assist > cap {
                drafts[pid]?.assist = cap
                scheduleSave(pid)
            }
        }
        var excess = totalAssists - totalG
        guard excess > 0 else { return }
        for player in players.reversed() where !injuredPlayerIds.contains(player.id) {
            if excess <= 0 { break }
            guard var d = drafts[player.id], d.assist > 0 else { continue }
            let cut = Swift.min(d.assist, excess)
            d.assist -= cut
            drafts[player.id] = d
            excess -= cut
            scheduleSave(player.id)
        }
    }

    private func scheduleSave(_ playerId: Int) {
        saveTasks[playerId]?.cancel()
        pendingSaveIds.insert(playerId)
        saveTasks[playerId] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000) // 0.6초 디바운스
            guard !Task.isCancelled else { return }
            self?.pendingSaveIds.remove(playerId)
            await self?.persist(playerId: playerId)
        }
    }

    // 화면 이탈 시 디바운스 대기분을 즉시 저장 — 마지막 입력 후 0.6초 안에 나가면 유실되는 문제 방지.
    // self를 강하게 잡아 저장이 끝날 때까지 ViewModel을 살려둔다.
    func flushPendingSaves() {
        let ids = pendingSaveIds
        pendingSaveIds.removeAll()
        for id in ids {
            saveTasks[id]?.cancel()
            Task { await self.persist(playerId: id) }
        }
    }

    // Task 취소(새 입력이 이전 저장을 대체)는 실패가 아니다 — 최신값은 새 Task가 저장하므로 알리지 않음
    private static func isCancellation(_ error: Error) -> Bool {
        if case APIError.unknown(let underlying) = error { return isCancellation(underlying) }
        return error is CancellationError || (error as? URLError)?.code == .cancelled
    }

    // draft가 서버에 반영될 때까지 저장. 선수당 1개 루프만 돌려 중복 생성·저장 유실 방지
    private func persist(playerId: Int) async {
        guard !savingPlayerIds.contains(playerId) else { return }
        savingPlayerIds.insert(playerId)
        defer { savingPlayerIds.remove(playerId) }

        while true {
            guard let d = drafts[playerId] else { return }

            // record가 아직 없으면: 최초 1회만 create, 이미 만들었으면 재조회로 id 복구
            if records.first(where: { $0.player == playerId }) == nil {
                if createdPlayerIds.contains(playerId) {
                    // create는 됐지만 id 확보 실패 상태 → 재조회로만 복구(중복 create 금지)
                    guard await refreshRecords(), records.contains(where: { $0.player == playerId }) else { return }
                } else {
                    do {
                        _ = try await APIClient.shared.request(
                            .createRecord(quarterId: quarter.id, playerId: playerId, min: d.min, goal: d.goal, assist: d.assist, yellowcard: d.yellowcard, redcard: d.redcard),
                            responseType: CodeResponse.self
                        )
                    } catch {
                        if !Self.isCancellation(error) { errorMessage = error.localizedDescription }
                        return
                    }
                    createdPlayerIds.insert(playerId)
                    // 새 record의 id를 확보해야 이후 저장이 update로 이어져 중복 생성을 막는다
                    guard await refreshRecords(), records.contains(where: { $0.player == playerId }) else { return }
                    // 방금 create로 저장된 값이 곧 d. 그 사이 입력이 안 바뀌었으면 종료
                    if drafts[playerId] == d { return }
                }
                continue  // 이제 record가 있으니 다음 루프에서 update 경로로
            }

            // 기존 record update
            guard let existing = records.first(where: { $0.player == playerId }) else { return }
            do {
                _ = try await APIClient.shared.request(
                    .updateRecord(id: existing.id, quarterId: quarter.id, playerId: playerId, min: d.min, goal: d.goal, assist: d.assist, yellowcard: d.yellowcard, redcard: d.redcard),
                    responseType: CodeResponse.self
                )
            } catch {
                if !Self.isCancellation(error) { errorMessage = error.localizedDescription }
                return
            }
            // 저장 도중 draft가 또 바뀌었으면 최신값으로 한 번 더 저장
            if drafts[playerId] == d { return }
        }
    }

    // record id 동기화 목적의 재조회. 성공 여부 반환. drafts(사용자 입력)는 덮어쓰지 않음
    private func refreshRecords() async -> Bool {
        do {
            let resp = try await APIClient.shared.request(
                .records(quarterId: quarter.id),
                responseType: ItemsResponse<Record>.self
            )
            records = resp.items ?? []
            return true
        } catch {
            // 취소가 아닌 실패만 안내 — 무음 실패 방지
            if !Self.isCancellation(error) { errorMessage = error.localizedDescription }
            return false
        }
    }

    func playerName(for playerId: Int) -> String {
        players.first(where: { $0.id == playerId })?.name ?? "알 수 없음"
    }

    func playerNumber(for playerId: Int) -> Int? {
        players.first(where: { $0.id == playerId })?.number
    }
}
