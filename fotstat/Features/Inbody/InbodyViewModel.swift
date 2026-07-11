import Foundation
import Combine

/// 인바디 값 표시 — 0(미측정)은 "-", 소수는 불필요한 0 없이("%g": 41.5, 4.03, 93).
func inbodyValue(_ v: Double, unit: String = "") -> String {
    v > 0 ? String(format: "%g", v) + unit : "-"
}

func inbodyValue(_ v: Int, unit: String = "") -> String {
    v > 0 ? "\(v)" + unit : "-"
}

@MainActor
final class InbodyViewModel: ObservableObject {
    @Published var inbodies: [Inbody] = []
    @Published var players: [Player] = []
    @Published var isLoading = false
    @Published var errorMessage: String?

    let team: Team

    init(team: Team) {
        self.team = team
    }

    /// 선수 id → 측정 이력 (검사일 최신순). inbodies 가 바뀔 때만 재계산되는 캐시 —
    /// 뷰가 선수 수만큼 반복 조회해도 전체 그룹핑을 다시 하지 않는다.
    @Published private(set) var byPlayer: [Int: [Inbody]] = [:]

    private func rebuildByPlayer() {
        byPlayer = Dictionary(grouping: inbodies, by: \.player)
            .mapValues { $0.sorted { $0.testdate > $1.testdate } }
    }

    /// 선수의 가장 최근 측정.
    func latest(for playerId: Int) -> Inbody? {
        byPlayer[playerId]?.first
    }

    func playerName(for playerId: Int) -> String { players.name(for: playerId) }

    func fetch() async {
        isLoading = true
        defer { isLoading = false }

        do {
            async let inbodiesReq = APIClient.shared.request(
                .inbodies(teamId: team.id),
                responseType: ItemsResponse<Inbody>.self
            )
            async let playersReq = APIClient.shared.request(
                .players(teamId: team.id),
                responseType: ItemsResponse<Player>.self
            )
            let (iResp, pResp) = try await (inbodiesReq, playersReq)
            inbodies = iResp.items ?? []
            players = pResp.items ?? []
            rebuildByPlayer()
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    // MARK: - Mutations

    /// 측정 1건 등록/수정. 성공 여부 반환 — 실패 시 폼을 닫지 않고 에러를 노출해야 한다.
    func save(_ draft: InbodyDraft) async -> Bool {
        guard let values = draft.parsedValues() else {
            errorMessage = "측정값은 0 이상의 숫자여야 하고, 인바디 점수는 정수여야 합니다."
            return false
        }
        do {
            let endpoint: Endpoint
            if let id = draft.id {
                endpoint = .updateInbody(id: id, playerId: draft.playerId, testdate: draft.testdate,
                                         height: values.height, weight: values.weight, muscle: values.muscle,
                                         fat: values.fat, rightleg: values.rightleg, leftleg: values.leftleg,
                                         score: values.score)
            } else {
                endpoint = .createInbody(playerId: draft.playerId, testdate: draft.testdate,
                                         height: values.height, weight: values.weight, muscle: values.muscle,
                                         fat: values.fat, rightleg: values.rightleg, leftleg: values.leftleg,
                                         score: values.score)
            }
            let resp = try await APIClient.shared.request(endpoint, responseType: CodeResponse.self)
            if let msg = resp.failureMessage {
                errorMessage = msg
                return false
            }
            await fetch()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// 시트 일괄 저장 — 값이 하나라도 있는 행만 upsert 한다. 성공 여부 반환.
    func saveBatch(testdate: String, drafts: [InbodyDraft]) async -> Bool {
        var entries: [[String: Any]] = []
        for draft in drafts where draft.hasValue {
            guard let v = draft.parsedValues() else {
                errorMessage = "'\(playerName(for: draft.playerId))' 행의 측정값은 0 이상의 숫자여야 하고, 인바디 점수는 정수여야 합니다."
                return false
            }
            entries.append([
                "player": draft.playerId, "testdate": testdate,
                "height": v.height, "weight": v.weight, "muscle": v.muscle, "fat": v.fat,
                "rightleg": v.rightleg, "leftleg": v.leftleg, "score": v.score
            ])
        }
        guard !entries.isEmpty else {
            errorMessage = "입력된 측정값이 없습니다."
            return false
        }
        do {
            let resp = try await APIClient.shared.request(
                .saveInbodyBatch(entries: entries),
                responseType: CodeResponse.self
            )
            if let msg = resp.failureMessage {
                errorMessage = msg
                return false
            }
            await fetch()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }

    /// 성공 여부 반환 — 실패 시 화면을 닫지 않고 에러를 노출해야 한다.
    func delete(id: Int) async -> Bool {
        do {
            let resp = try await APIClient.shared.request(.deleteInbody(id: id), responseType: CodeResponse.self)
            if let msg = resp.failureMessage {
                errorMessage = msg
                return false
            }
            await fetch()
            return true
        } catch {
            errorMessage = error.localizedDescription
            return false
        }
    }
}

// MARK: - InbodyDraft

/// 측정 입력값. 값 필드는 decimalPad 입력 원문(String)을 그대로 보관하고
/// 저장 시점에 파싱한다. 빈칸 = 0(미측정). id 가 nil 이면 신규.
struct InbodyDraft: Identifiable {
    var id: Int? = nil
    var playerId: Int
    var testdate: String
    var height: String = ""
    var weight: String = ""
    var muscle: String = ""
    var fat: String = ""
    var rightleg: String = ""
    var leftleg: String = ""
    var score: String = ""

    static func from(_ e: Inbody) -> InbodyDraft {
        func s(_ v: Double) -> String { v > 0 ? String(format: "%g", v) : "" }
        return InbodyDraft(
            id: e.id, playerId: e.player, testdate: e.testdate,
            height: s(e.height), weight: s(e.weight), muscle: s(e.muscle), fat: s(e.fat),
            rightleg: s(e.rightleg), leftleg: s(e.leftleg),
            score: e.score > 0 ? "\(e.score)" : ""
        )
    }

    /// 값이 하나라도 입력된 행인가 — 시트 저장 시 이 행만 전송한다.
    var hasValue: Bool {
        ![height, weight, muscle, fat, rightleg, leftleg, score]
            .allSatisfy { $0.trimmingCharacters(in: .whitespaces).isEmpty }
    }

    struct Values {
        let height, weight, muscle, fat, rightleg, leftleg: Double
        let score: Int
    }

    /// 문자열 → 숫자. 빈칸은 0(미측정), 비수치·음수·비유한값이 있으면 nil.
    /// 점수는 정수만 허용 — 소수 입력이 조용히 절삭되지 않게 검증 단계에서 거부한다.
    func parsedValues() -> Values? {
        func num(_ raw: String) -> Double? {
            let trimmed = raw.trimmingCharacters(in: .whitespaces)
                // 쉼표 소수점 로케일의 decimalPad 입력도 받아들인다
                .replacingOccurrences(of: ",", with: ".")
            if trimmed.isEmpty { return 0 }
            guard let n = Double(trimmed), n.isFinite, n >= 0 else { return nil }
            return n
        }
        guard let h = num(height), let w = num(weight), let m = num(muscle), let f = num(fat),
              let r = num(rightleg), let l = num(leftleg), let sc = num(score),
              sc.truncatingRemainder(dividingBy: 1) == 0 else { return nil }
        return Values(height: h, weight: w, muscle: m, fat: f, rightleg: r, leftleg: l, score: Int(sc))
    }
}
