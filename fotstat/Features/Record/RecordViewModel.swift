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
    @Published var isLoading = false
    @Published var errorMessage: String?

    let quarter: Quarter
    let team: Team
    private var savingPlayerIds: Set<Int> = []        // 저장 루프 중복 진입 방지
    private var createdPlayerIds: Set<Int> = []       // 이미 create 한 선수 — 중복 생성 방지
    private var saveTasks: [Int: Task<Void, Never>] = [:]

    init(quarter: Quarter, team: Team) {
        self.quarter = quarter
        self.team = team
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
            let (rResp, pResp) = try await (recordsReq, playersReq)
            records = rResp.items ?? []
            players = pResp.items ?? []
            rebuildDrafts()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // 서버 records를 drafts에 반영. playerId 기준이라 서버에 같은 선수 record가 중복돼도 마지막 것만 집계(방어)
    private func rebuildDrafts() {
        var next: [Int: Draft] = [:]
        for r in records {
            next[r.player] = Draft(min: r.min, goal: r.goal, assist: r.assist, yellowcard: r.yellowcard, redcard: r.redcard)
        }
        drafts = next
    }

    // 카드 값이 바뀔 때마다 즉시 호출 → draft 갱신(합계 즉시 반영) 후 네트워크 저장은 디바운스
    func updateDraft(playerId: Int, min: Int, goal: Int, assist: Int, yellowcard: Int, redcard: Int) {
        drafts[playerId] = Draft(min: min, goal: goal, assist: assist, yellowcard: yellowcard, redcard: redcard)
        saveTasks[playerId]?.cancel()
        saveTasks[playerId] = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 600_000_000) // 0.6초 디바운스
            guard !Task.isCancelled else { return }
            await self?.persist(playerId: playerId)
        }
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
                        errorMessage = error.localizedDescription
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
                errorMessage = error.localizedDescription
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
            errorMessage = error.localizedDescription   // 무음 실패 방지 — 저장 중단을 사용자에게 안내
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
