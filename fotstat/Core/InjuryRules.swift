import Foundation

/// 부상 기간 ↔ 경기일 판정 규칙의 단일 원천. 백엔드 injuryConflict, 웹 lib/injury 와
/// 동일한 규칙을 iOS 안에서 한곳에 모은다. 날짜는 모두 "yyyy-MM-dd" 문자열이며
/// 형식이 고정폭이라 문자열 비교로 대소를 판단한다.
enum InjuryRules {
    /// 경기일(day)이 부상 spell (start, end] 안에 드는가.
    /// 발생일 당일 경기는 뛴 것으로 보고 제외(start < day), 복귀일 당일까지는 결장(day <= end).
    /// end 가 "" 이면 상한 없음(복귀 전 — 열린 구간).
    static func spellCovers(day: String, start: String, end: String) -> Bool {
        guard !start.isEmpty, !day.isEmpty, start < day else { return false }
        return end.isEmpty || day <= end
    }

    /// 특정 경기일에 부상 중인 선수 id 집합. 복귀 전(returndate "")이면 상한 없이 포함된다.
    static func injuredPlayerIds(injuries: [Injury], on matchdate: String) -> Set<Int> {
        let day = matchdate.dayPrefix
        guard !day.isEmpty else { return [] }
        var ids: Set<Int> = []
        for injury in injuries where spellCovers(
            day: day,
            start: (injury.startdate ?? "").dayPrefix,
            end: (injury.returndate ?? "").dayPrefix
        ) {
            ids.insert(injury.player)
        }
        return ids
    }

    /// 한 부상으로 결장한 팀 경기 수. 복귀 전이면 아직 열리지 않은 미래 경기를 세지 않도록
    /// 상한을 오늘(today)로 둔다.
    static func absentGames(for injury: Injury, matches: [Match], today: String = Date.todayYMD) -> Int {
        let start = (injury.startdate ?? "").dayPrefix
        guard !start.isEmpty else { return 0 }
        let end = injury.isActive ? today : (injury.returndate ?? "").dayPrefix
        guard !end.isEmpty else { return 0 }
        return matches.filter {
            spellCovers(day: $0.matchdate.dayPrefix, start: start, end: end)
        }.count
    }
}
