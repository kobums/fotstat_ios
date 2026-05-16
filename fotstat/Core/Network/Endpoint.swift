import Foundation

enum HTTPMethod: String {
    case GET, POST, PUT, DELETE
}

struct Endpoint {
    let path: String
    let method: HTTPMethod
    var body: [String: Any]? = nil
}

// MARK: - Auth

extension Endpoint {
    static func login(email: String, passwd: String) -> Endpoint {
        let e = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? email
        let p = passwd.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? passwd
        return Endpoint(path: "/jwt?email=\(e)&password=\(p)", method: .GET)
    }

    static func register(email: String, password: String, name: String) -> Endpoint {
        Endpoint(path: "/user", method: .POST, body: [
            "email": email, "password": password, "name": name
        ])
    }
}

// MARK: - Team

extension Endpoint {
    static func teams(userId: Int) -> Endpoint {
        Endpoint(path: "/team?user=\(userId)", method: .GET)
    }

    static func createTeam(userId: Int, name: String) -> Endpoint {
        Endpoint(path: "/team", method: .POST, body: ["user": userId, "name": name])
    }

    static func updateTeam(id: Int, userId: Int, name: String) -> Endpoint {
        Endpoint(path: "/team", method: .PUT, body: ["id": id, "user": userId, "name": name])
    }

    static func deleteTeam(id: Int) -> Endpoint {
        Endpoint(path: "/team", method: .DELETE, body: ["id": id])
    }
}

// MARK: - Player

extension Endpoint {
    static func players(teamId: Int) -> Endpoint {
        Endpoint(path: "/player?team=\(teamId)", method: .GET)
    }

    static func createPlayer(teamId: Int, name: String, number: Int, position: String? = nil) -> Endpoint {
        var body: [String: Any] = ["team": teamId, "name": name, "number": number]
        if let position { body["position"] = position }
        return Endpoint(path: "/player", method: .POST, body: body)
    }

    static func updatePlayer(id: Int, teamId: Int, name: String, number: Int, position: String? = nil) -> Endpoint {
        var body: [String: Any] = ["id": id, "team": teamId, "name": name, "number": number]
        if let position { body["position"] = position }
        return Endpoint(path: "/player", method: .PUT, body: body)
    }

    static func deletePlayer(id: Int) -> Endpoint {
        Endpoint(path: "/player", method: .DELETE, body: ["id": id])
    }
}

// MARK: - Match

extension Endpoint {
    static func matches(teamId: Int) -> Endpoint {
        Endpoint(path: "/match?team=\(teamId)", method: .GET)
    }

    static func createMatch(teamId: Int, awayname: String, matchdate: String) -> Endpoint {
        Endpoint(path: "/match", method: .POST, body: [
            "team": teamId, "awayname": awayname, "matchdate": matchdate
        ])
    }

    static func updateMatch(id: Int, teamId: Int, awayname: String, matchdate: String) -> Endpoint {
        Endpoint(path: "/match", method: .PUT, body: [
            "id": id, "team": teamId, "awayname": awayname, "matchdate": matchdate
        ])
    }

    static func deleteMatch(id: Int) -> Endpoint {
        Endpoint(path: "/match", method: .DELETE, body: ["id": id])
    }
}

// MARK: - Quarter

extension Endpoint {
    static func quarters(matchId: Int) -> Endpoint {
        Endpoint(path: "/quarter?match=\(matchId)", method: .GET)
    }

    static func createQuarter(matchId: Int, number: Int, duration: Int) -> Endpoint {
        Endpoint(path: "/quarter", method: .POST, body: ["match": matchId, "number": number, "duration": duration])
    }

    static func updateQuarterAwayGoals(id: Int, awaygoals: Int) -> Endpoint {
        Endpoint(path: "/quarter/awaygoals", method: .PUT, body: ["id": id, "awaygoals": awaygoals])
    }

    static func deleteQuarter(id: Int) -> Endpoint {
        Endpoint(path: "/quarter", method: .DELETE, body: ["id": id])
    }
}

// MARK: - Record

extension Endpoint {
    static func records(quarterId: Int) -> Endpoint {
        Endpoint(path: "/record?quarter=\(quarterId)", method: .GET)
    }

    static func recordsByPlayer(playerId: Int) -> Endpoint {
        Endpoint(path: "/record?player=\(playerId)", method: .GET)
    }

    static func createRecord(quarterId: Int, playerId: Int, min: Int, goal: Int, assist: Int) -> Endpoint {
        Endpoint(path: "/record", method: .POST, body: [
            "quarter": quarterId, "player": playerId, "min": min, "goal": goal, "assist": assist
        ])
    }

    static func updateRecord(id: Int, quarterId: Int, playerId: Int, min: Int, goal: Int, assist: Int) -> Endpoint {
        Endpoint(path: "/record/stats", method: .PUT, body: [
            "id": id, "min": min, "goal": goal, "assist": assist
        ])
    }

    static func deleteRecord(id: Int) -> Endpoint {
        Endpoint(path: "/record", method: .DELETE, body: ["id": id])
    }
}

// MARK: - Stats (not yet implemented in backend)

extension Endpoint {
    static func teamStats(teamId: Int) -> Endpoint {
        Endpoint(path: "/teams/\(teamId)/stats", method: .GET)
    }
    static func playerStats(playerId: Int) -> Endpoint {
        Endpoint(path: "/players/\(playerId)/stats", method: .GET)
    }
    static func matchStats(matchId: Int) -> Endpoint {
        Endpoint(path: "/matches/\(matchId)/stats", method: .GET)
    }
}
