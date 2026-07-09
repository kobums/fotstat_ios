import Foundation

// MARK: - Auth

struct AuthResponse: Decodable {
    let code: String
    let token: String?
    let refresh: String?
    let user: User?
    let message: String?
}

struct User: Decodable, Identifiable {
    let id: Int
    let email: String
    let name: String
}

// MARK: - Team

struct Team: Decodable, Identifiable, Hashable {
    let id: Int
    let user: Int
    let name: String
    let duration: Int?   // 쿼터 기본 시간(분) — 쿼터 추가 시 프리필. 구서버 응답엔 없음
    let createddate: String?
}

// MARK: - Player

struct Player: Decodable, Identifiable {
    let id: Int
    let team: Int
    let name: String
    let number: Int?
    let birthdate: String?
    let pos: String?

    enum CodingKeys: String, CodingKey {
        case id, team, name, number, birthdate
        case pos = "position"
    }
}

extension Player {
    /// 생일 "yyyy-MM-dd"(뒤에 시간이 붙어도 무방)에서 (월, 일) 추출 — 매년 반복되는 생일 판정용.
    /// 형식이 어긋나면 nil. (2월 29일생은 평년 달력에 해당 날짜가 없어 윤년에만 표시된다.)
    var birthMonthDay: (month: Int, day: Int)? {
        guard let birthdate, !birthdate.isEmpty else { return nil }
        let parts = birthdate.dayPrefix.split(separator: "-")
        guard parts.count == 3,
              let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month), (1...31).contains(day) else { return nil }
        return (month, day)
    }

    /// 생일 문자열에서 출생 연도 — 나이 표시용. 형식이 어긋나면 nil.
    var birthYear: Int? {
        guard let birthdate, !birthdate.isEmpty else { return nil }
        let parts = birthdate.dayPrefix.split(separator: "-")
        guard parts.count == 3, let year = Int(parts[0]), year > 0 else { return nil }
        return year
    }
}

extension Sequence where Element == Player {
    /// id로 선수 이름 조회. 없으면 "알 수 없음".
    func name(for id: Int) -> String {
        first(where: { $0.id == id })?.name ?? "알 수 없음"
    }

    /// id로 선수 등번호 조회. 없으면 nil.
    func number(for id: Int) -> Int? {
        first(where: { $0.id == id })?.number
    }
}

// MARK: - Match

struct Match: Decodable, Identifiable, Hashable {
    let id: Int
    let team: Int
    let awayname: String
    let matchdate: String

    var parsedDate: Date? {
        DateFormats.dateTime.date(from: matchdate)
    }

    /// 예정 경기 여부 (경기 시각이 현재보다 미래). parsedDate 실패 시 과거로 간주.
    var isUpcoming: Bool { (parsedDate ?? .distantPast) > Date() }
}

extension Sequence where Element == Match {
    /// 예정 경기만, 경기일 오름차순.
    func upcoming() -> [Match] {
        filter { $0.isUpcoming }
            .sorted { ($0.parsedDate ?? .distantPast) < ($1.parsedDate ?? .distantPast) }
    }

    /// 지난 경기만, 경기일 내림차순.
    func past() -> [Match] {
        filter { !$0.isUpcoming }
            .sorted { ($0.parsedDate ?? .distantPast) > ($1.parsedDate ?? .distantPast) }
    }
}

// MARK: - Quarter

struct Quarter: Decodable, Identifiable, Hashable {
    let id: Int
    let match: Int
    let number: Int
    let duration: Int
    let awaygoals: Int
}

// MARK: - Record

struct Record: Decodable, Identifiable {
    let id: Int
    let quarter: Int
    let player: Int
    let min: Int
    let goal: Int
    let assist: Int
    let yellowcard: Int
    let redcard: Int
}

// MARK: - Injury

struct Injury: Decodable, Identifiable, Hashable {
    let id: Int
    let player: Int
    let type: String?
    let startdate: String?
    let returndate: String?
    let memo: String?

    /// 복귀일이 비어 있으면 아직 부상 중(복귀 전).
    var isActive: Bool { (returndate ?? "").isEmpty }
}

// MARK: - Stats (not yet implemented in backend)

struct TeamStats: Decodable {
    let matchCount: Int
    let totalGoal: Int
    let totalAssist: Int
    let players: [PlayerStats]
    var wins: Int = 0
    var draws: Int = 0
    var losses: Int = 0
    var totalConceded: Int = 0   // 기간 내 실점(상대 골) 합계
}

struct PlayerStats: Decodable, Identifiable, Hashable {
    let id: Int
    let name: String
    let number: Int?
    let position: String?
    let goal: Int
    let assist: Int
    let min: Int
    var games: Int = 0
    var absentGames: Int = 0   // 부상으로 결장한 경기 수
}

struct MatchStats: Decodable {
    let matchId: Int
    let awayName: String
    let matchDate: String
    let players: [PlayerStats]
}

// MARK: - Response Wrappers

struct ItemsResponse<T: Decodable>: Decodable {
    let code: String
    let items: [T]?
    let total: Int?   // page=1 페이지네이션 응답에서만 채워짐
}

struct ItemResponse<T: Decodable>: Decodable {
    let code: String
    let item: T?
}

struct CodeResponse: Decodable {
    let code: String
}

typealias MessageResponse = CodeResponse
