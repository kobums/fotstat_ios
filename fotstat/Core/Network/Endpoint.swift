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
    static func appleLogin(identityToken: String, authorizationCode: String, name: String) -> Endpoint {
        var body: [String: Any] = ["identityToken": identityToken]
        if !authorizationCode.isEmpty { body["authorizationCode"] = authorizationCode }
        if !name.isEmpty { body["name"] = name }
        return Endpoint(path: "/apple-auth", method: .POST, body: body)
    }

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

    static func guest() -> Endpoint {
        Endpoint(path: "/guest", method: .POST)
    }

    static func upgradeAccount(email: String, password: String, name: String) -> Endpoint {
        Endpoint(path: "/account/upgrade", method: .POST, body: [
            "email": email, "password": password, "name": name
        ])
    }

    static func deleteAccount() -> Endpoint {
        Endpoint(path: "/account", method: .DELETE)
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

    // 예정 경기: matchdate >= now, 가까운 순. 페이지네이션 없이 전체.
    static func matchesUpcoming(teamId: Int, after: String) -> Endpoint {
        Endpoint(path: matchListPath(teamId: teamId,
                                     dateKey: "startmatchdate", date: after,
                                     orderby: "matchdate asc"), method: .GET)
    }

    // 지난 경기: matchdate <= now, 최신순, 페이지네이션. page=1 응답에 total 포함.
    static func matchesPast(teamId: Int, before: String, page: Int, pagesize: Int) -> Endpoint {
        Endpoint(path: matchListPath(teamId: teamId,
                                     dateKey: "endmatchdate", date: before,
                                     orderby: "matchdate desc",
                                     page: page, pagesize: pagesize), method: .GET)
    }

    // URLComponents로 쿼리를 구성해 날짜·orderby의 공백/특수문자를 안전하게 인코딩
    private static func matchListPath(teamId: Int, dateKey: String, date: String,
                                      orderby: String, page: Int? = nil, pagesize: Int? = nil) -> String {
        var comps = URLComponents()
        comps.path = "/match"
        var items = [
            URLQueryItem(name: "team", value: "\(teamId)"),
            URLQueryItem(name: dateKey, value: date),
        ]
        if let page, let pagesize {
            items.append(URLQueryItem(name: "page", value: "\(page)"))
            items.append(URLQueryItem(name: "pagesize", value: "\(pagesize)"))
        }
        items.append(URLQueryItem(name: "orderby", value: orderby))
        comps.queryItems = items
        return comps.string ?? "/match?team=\(teamId)"
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
