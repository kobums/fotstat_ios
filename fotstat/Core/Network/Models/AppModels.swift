import Foundation

// MARK: - Auth

struct AuthResponse: Decodable {
    let code: String
    let token: String?
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
    let pos: String?

    enum CodingKeys: String, CodingKey {
        case id, team, name, number
        case pos = "position"
    }
}

// MARK: - Match

struct Match: Decodable, Identifiable, Hashable {
    let id: Int
    let team: Int
    let awayname: String
    let matchdate: String

    var parsedDate: Date? {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd HH:mm:ss"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.date(from: matchdate)
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
}

struct ItemResponse<T: Decodable>: Decodable {
    let code: String
    let item: T?
}

struct CodeResponse: Decodable {
    let code: String
}

typealias MessageResponse = CodeResponse
