import Foundation
import Combine

extension Notification.Name {
    /// 훈련·참석 변경 시 홈 달력 등 다른 탭 화면이 재조회하도록 알림
    static let trainingChanged = Notification.Name("fotstat.trainingChanged")
}

@MainActor
final class TrainingViewModel: ObservableObject {
    @Published var trainings: [Training] = []
    @Published var attendances: [Attendance] = []   // 팀 전체 — 세션별 그룹핑은 클라이언트
    @Published var players: [Player] = []
    @Published var injuries: [Injury] = []          // 훈련일 부상 선수 비활성 처리용
    @Published var isLoading = false
    @Published var errorMessage: String?

    let team: Team

    init(team: Team) {
        self.team = team
    }

    /// 훈련 일시 최신순.
    var sortedTrainings: [Training] {
        trainings.sorted { $0.trainingdate > $1.trainingdate }
    }

    func fetch() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let trainingsReq = APIClient.shared.request(
                .trainings(teamId: team.id),
                responseType: ItemsResponse<Training>.self
            )
            async let attendancesReq = APIClient.shared.request(
                .attendances(teamId: team.id),
                responseType: ItemsResponse<Attendance>.self
            )
            async let playersReq = APIClient.shared.request(
                .players(teamId: team.id),
                responseType: ItemsResponse<Player>.self
            )
            async let injuriesReq = APIClient.shared.request(
                .injuries(teamId: team.id),
                responseType: ItemsResponse<Injury>.self
            )
            let (tResp, aResp, pResp) = try await (trainingsReq, attendancesReq, playersReq)
            trainings = tResp.items ?? []
            attendances = aResp.items ?? []
            players = pResp.items ?? []
            // injuries는 참석 체크의 비활성 표시에만 쓰므로 실패해도 목록·등록 흐름을 막지 않는다
            if let iResp = try? await injuriesReq {
                injuries = iResp.items ?? []
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func playerName(for playerId: Int) -> String { players.name(for: playerId) }

    func playerNumber(for playerId: Int) -> Int? { players.number(for: playerId) }

    /// 특정 훈련의 참석 목록.
    func attendances(for trainingId: Int) -> [Attendance] {
        attendances.filter { $0.training == trainingId }
    }

    /// 훈련일에 부상 기간이 걸친 선수 id — 규칙은 InjuryRules(백엔드 trainingInjuryConflict와 동일).
    func injuredPlayerIds(on trainingdate: String) -> Set<Int> {
        InjuryRules.injuredPlayerIds(injuries: injuries, on: trainingdate)
    }

    // MARK: - 선수별 참석 집계 (클라이언트 — 웹 lib/training.ts 와 동일 규칙)

    struct PlayerTrainingStats {
        let attended: Int
        let held: Int      // 분모 — 지금까지 열린 훈련 수 (미래 훈련 제외)
        let totalMin: Int
        var rate: Int { held == 0 ? 0 : Int((Double(attended) / Double(held) * 100).rounded()) }
    }

    func stats(for playerId: Int, today: String = Date.todayYMD) -> PlayerTrainingStats {
        let heldIds = Set(trainings.filter { $0.trainingdate.dayPrefix <= today }.map(\.id))
        let mine = attendances.filter { $0.player == playerId && heldIds.contains($0.training) }
        return PlayerTrainingStats(
            attended: mine.count,
            held: heldIds.count,
            totalMin: mine.reduce(0) { $0 + $1.min }
        )
    }

    // MARK: - Mutations

    func save(_ draft: TrainingDraft) async -> Bool {
        let dateStr = DateFormats.dateTime.string(from: draft.date)
        do {
            let endpoint: Endpoint
            if let id = draft.id {
                endpoint = .updateTraining(id: id, teamId: team.id, trainingdate: dateStr)
            } else {
                endpoint = .createTraining(teamId: team.id, trainingdate: dateStr)
            }
            let resp = try await APIClient.shared.request(endpoint, responseType: CodeResponse.self)
            if let msg = resp.failureMessage {
                errorMessage = msg
                return false
            }
            await fetch()
            NotificationCenter.default.post(name: .trainingChanged, object: nil)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// 성공 여부 반환 — 실패 시 폼을 닫지 않고 에러를 노출해야 한다.
    func delete(id: Int) async -> Bool {
        do {
            let resp = try await APIClient.shared.request(.deleteTraining(id: id), responseType: CodeResponse.self)
            if let msg = resp.failureMessage {
                errorMessage = msg
                return false
            }
            await fetch()
            NotificationCenter.default.post(name: .trainingChanged, object: nil)
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// 참석 체크 저장 — 두 요청이 원자적이지 않으므로 upsert를 먼저 보내
    /// 중간 실패가 '기록 유실'이 아니라 '해제 미반영'으로 남게 한다. 성공 여부 반환.
    func saveAttendances(
        trainingId: Int,
        upserts: [(player: Int, min: Int)],
        deletes: [Int]
    ) async -> Bool {
        do {
            // 백엔드는 부상 충돌·권한 거부를 HTTP 200 + code:"error"로 내려주므로
            // 응답 code까지 검사해야 "저장된 척 닫히는" 실패를 막을 수 있다
            if !upserts.isEmpty {
                let resp = try await APIClient.shared.request(
                    .upsertAttendances(trainingId: trainingId, entries: upserts),
                    responseType: CodeResponse.self
                )
                if let msg = resp.failureMessage {
                    await fetch()
                    errorMessage = msg
                    return false
                }
            }
            if !deletes.isEmpty {
                let resp = try await APIClient.shared.request(
                    .deleteAttendances(ids: deletes),
                    responseType: CodeResponse.self
                )
                if let msg = resp.failureMessage {
                    await fetch()
                    errorMessage = msg
                    return false
                }
            }
            await fetch()
            // 실제로 변경 요청을 보낸 경우에만 다른 화면 재조회를 유발한다
            if !upserts.isEmpty || !deletes.isEmpty {
                NotificationCenter.default.post(name: .trainingChanged, object: nil)
            }
            return true
        } catch {
            let message = error.localizedDescription
            // 부분 실패(upsert만 성공 등) 시에도 화면이 서버 상태와 어긋나지 않게 재조회
            await fetch()
            errorMessage = message
            return false
        }
    }
}

/// 훈련 등록/수정 폼 입력값. id 가 nil 이면 신규 등록.
struct TrainingDraft: Identifiable {
    var id: Int? = nil
    var date: Date = Date()

    static func new() -> TrainingDraft { TrainingDraft() }

    static func from(_ training: Training) -> TrainingDraft {
        TrainingDraft(id: training.id, date: training.parsedDate ?? Date())
    }
}
