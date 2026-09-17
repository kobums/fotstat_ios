import Foundation

// 선수 상세의 "팀 내 위치" — fotmob 시즌 성적 카드의 순위 바를 팀 단위로 옮긴 것.
// 지표별로 선수 값·팀 평균·상위 %·순위를 만든다. 웹 features/stats/playerRank.ts 미러.

/// 합계 / 경기당 토글 (fotmob "합계 | 90분당"의 팀 기록 버전 — 쿼터 길이가
/// 팀마다 달라 90분 환산 대신 경기당으로 둔다).
enum RankMode: String, CaseIterable, Identifiable {
    case total = "합계"
    case perGame = "경기당"
    var id: String { rawValue }
}

struct RankMetric: Identifiable {
    let key: String
    let label: String
    /// 선수 값 (mode 반영).
    let value: Double
    /// 팀 평균 — 출전 기록이 있는 선수들만의 평균.
    let avg: Double
    /// 스쿼드 전원 기준 상위 X% (동률은 같은 퍼센타일).
    let pct: Int
    /// 1위부터의 순위 — 동률은 같은 순위(1224 방식).
    let rank: Int
    /// 순위 모집단 크기(스쿼드 인원).
    let total: Int
    /// 비례 바 기준값 — 스쿼드 1위 값(0이면 1).
    let max: Double
    let unit: String
    let decimals: Int
    var id: String { key }

    var valueText: String { format(value) }
    var avgText: String { format(avg) }

    private func format(_ v: Double) -> String {
        decimals == 0 ? "\(Int(v.rounded()))\(unit)" : String(format: "%.\(decimals)f\(unit)", v)
    }
}

enum PlayerRank {
    /// 스쿼드가 작으면 "상위 N%"가 무의미해 순위로 바꿔 표기한다.
    static let pctMinSquad = 5

    /// 1224 방식 순위: 나보다 큰 값의 수 + 1.
    static func teamRank(_ value: Double, in all: [Double]) -> (rank: Int, total: Int) {
        (all.filter { $0 > value }.count + 1, all.count)
    }

    /// 상위 X% = ceil((나보다 큰 수 + 1) / 전체 × 100), 최소 1. 빈 모집단은 100.
    static func topPercent(_ value: Double, in all: [Double]) -> Int {
        guard !all.isEmpty else { return 100 }
        let better = all.filter { $0 > value }.count
        return Swift.max(1, Int(ceil(Double(better + 1) / Double(all.count) * 100)))
    }

    static func label(_ m: RankMetric) -> String {
        // 값이 0이면 순위를 매기지 않는다 — 전원이 0일 때 모두 공동 1위가 되어
        // "0% · 상위 5%" 같은 배지가 붙는 것을 막는다(웹 rankLabel 과 같은 규칙).
        if m.total == 0 || m.value <= 0 { return "-" }
        return m.total >= pctMinSquad ? "상위 \(m.pct)%" : "\(m.rank)위 / \(m.total)명"
    }

    private struct MetricDef {
        let key: String
        let label: String
        let pick: (PlayerStats) -> Int
        var unit: String = ""
        /// 경기당 모드의 소수 자릿수. 분 단위는 소수가 어색해 정수로 반올림한다.
        var perGameDecimals: Int = 2
    }

    private static let statMetrics: [MetricDef] = [
        .init(key: "goal", label: "골", pick: { $0.goal }),
        .init(key: "assist", label: "도움", pick: { $0.assist }),
        .init(key: "points", label: "공격P", pick: { $0.goal + $0.assist }),
        .init(key: "min", label: "출전 시간", pick: { $0.min }, unit: "′", perGameDecimals: 0),
    ]

    private static func mean(_ values: [Double]) -> Double {
        values.isEmpty ? 0 : values.reduce(0, +) / Double(values.count)
    }

    /// 선수의 팀 내 위치 지표 목록.
    /// - 순위·상위%는 스쿼드 전원 기준. 팀 평균은 출전 기록이 있는 선수만
    ///   (0경기 선수가 평균을 끌어내리지 않게).
    /// - `attendance`(선수 id → 참석률 %)가 있으면 참석률 지표를 덧붙인다 — 모드와 무관하게 %.
    ///   참석률 평균만은 전원 기준: 0%(전 결석)도 유효한 값이라 출전 여부와 무관하다.
    static func metrics(
        playerId: Int,
        squad: [PlayerStats],
        mode: RankMode,
        attendance: [Int: Int]? = nil
    ) -> [RankMetric] {
        guard let me = squad.first(where: { $0.id == playerId }) else { return [] }
        let played = squad.filter { $0.games > 0 }

        var result: [RankMetric] = statMetrics.map { def in
            let valueOf: (PlayerStats) -> Double = { p in
                let raw = Double(def.pick(p))
                return mode == .perGame ? (p.games > 0 ? raw / Double(p.games) : 0) : raw
            }
            let all = squad.map(valueOf)
            let value = valueOf(me)
            let (rank, total) = teamRank(value, in: all)
            let top = all.max() ?? 0
            return RankMetric(
                key: def.key, label: def.label, value: value,
                avg: mean(played.map(valueOf)),
                pct: topPercent(value, in: all), rank: rank, total: total,
                max: top > 0 ? top : 1, unit: def.unit,
                decimals: mode == .perGame ? def.perGameDecimals : 0
            )
        }

        if let attendance {
            let rateOf: (PlayerStats) -> Double = { Double(attendance[$0.id] ?? 0) }
            let all = squad.map(rateOf)
            let value = rateOf(me)
            let (rank, total) = teamRank(value, in: all)
            result.append(RankMetric(
                key: "attendance", label: "훈련 참석률", value: value,
                avg: mean(all), pct: topPercent(value, in: all), rank: rank, total: total,
                max: 100, unit: "%", decimals: 0
            ))
        }
        return result
    }
}
