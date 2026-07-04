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
        let parts = birthdate.prefix(10).split(separator: "-")
        guard parts.count == 3,
              let month = Int(parts[1]), let day = Int(parts[2]),
              (1...12).contains(month), (1...31).contains(day) else { return nil }
        return (month, day)
    }

    /// 생일 문자열에서 출생 연도 — 나이 표시용. 형식이 어긋나면 nil.
    var birthYear: Int? {
        guard let birthdate, !birthdate.isEmpty else { return nil }
        let parts = birthdate.prefix(10).split(separator: "-")
        guard parts.count == 3, let year = Int(parts[0]), year > 0 else { return nil }
        return year
    }
}

// MARK: - Match

struct Match: Decodable, Identifiable, Hashable {
    let id: Int
    let team: Int
    let awayname: String
    let matchdate: String

    // 매 호출마다 DateFormatter를 새로 만들지 않도록 static 캐시 (parsedDate는 렌더마다 빈번히 호출됨)
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    var parsedDate: Date? {
        Match.dateFormatter.date(from: matchdate)
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
