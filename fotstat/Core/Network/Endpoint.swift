import Foundation

enum HTTPMethod: String {
    case GET, POST, PUT, DELETE
}

struct Endpoint {
    let path: String
    let method: HTTPMethod
    var body: [String: Any]? = nil
    /// batch 엔드포인트(insertbatch/deletebatch)용 JSON 배열 본문.
    /// 설정되면 body 대신 이 배열이 직렬화된다.
    var arrayBody: [[String: Any]]? = nil
    /// Whether this call carries the user session. Public auth endpoints
    /// (login, register, guest, refresh) set this false so the client neither
    /// attaches a stale token nor tries to auto-refresh on a 401.
    var requiresAuth: Bool = true
}

// MARK: - Auth

extension Endpoint {
    static func appleLogin(identityToken: String, authorizationCode: String, name: String) -> Endpoint {
        var body: [String: Any] = ["identityToken": identityToken]
        if !authorizationCode.isEmpty { body["authorizationCode"] = authorizationCode }
        if !name.isEmpty { body["name"] = name }
        return Endpoint(path: "/apple-auth", method: .POST, body: body, requiresAuth: false)
    }

    static func login(email: String, passwd: String) -> Endpoint {
        let e = email.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? email
        let p = passwd.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? passwd
        return Endpoint(path: "/jwt?email=\(e)&password=\(p)", method: .GET, requiresAuth: false)
    }

    static func register(email: String, password: String, name: String) -> Endpoint {
        Endpoint(path: "/user", method: .POST, body: [
            "email": email, "password": password, "name": name
        ], requiresAuth: false)
    }

    static func guest() -> Endpoint {
        Endpoint(path: "/guest", method: .POST, requiresAuth: false)
    }

    static func refresh(token: String) -> Endpoint {
        Endpoint(path: "/refresh", method: .POST, body: ["refresh": token], requiresAuth: false)
    }

    static func upgradeAccount(email: String, password: String, name: String) -> Endpoint {
        Endpoint(path: "/account/upgrade", method: .POST, body: [
            "email": email, "password": password, "name": name
        ])
    }

    static func deleteAccount() -> Endpoint {
        Endpoint(path: "/account", method: .DELETE)
    }

    static func logout() -> Endpoint {
        Endpoint(path: "/logout", method: .POST)
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

    static func updateTeam(id: Int, userId: Int, name: String, duration: Int? = nil) -> Endpoint {
        var body: [String: Any] = ["id": id, "user": userId, "name": name]
        if let duration { body["duration"] = duration }
        return Endpoint(path: "/team", method: .PUT, body: body)
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

    static func createPlayer(teamId: Int, name: String, number: Int, position: String? = nil, birthdate: String? = nil) -> Endpoint {
        var body: [String: Any] = ["team": teamId, "name": name, "number": number]
        if let position { body["position"] = position }
        if let birthdate { body["birthdate"] = birthdate }
        return Endpoint(path: "/player", method: .POST, body: body)
    }

    static func updatePlayer(id: Int, teamId: Int, name: String, number: Int, position: String? = nil, birthdate: String? = nil) -> Endpoint {
        var body: [String: Any] = ["id": id, "team": teamId, "name": name, "number": number]
        if let position { body["position"] = position }
        // Always send birthdate on update so clearing it persists (nil/"" -> backend NULL).
        body["birthdate"] = birthdate ?? ""
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

    static func createRecord(quarterId: Int, playerId: Int, min: Int, goal: Int, assist: Int, yellowcard: Int, redcard: Int) -> Endpoint {
        Endpoint(path: "/record", method: .POST, body: [
            "quarter": quarterId, "player": playerId, "min": min, "goal": goal, "assist": assist,
            "yellowcard": yellowcard, "redcard": redcard
        ])
    }

    static func updateRecord(id: Int, quarterId: Int, playerId: Int, min: Int, goal: Int, assist: Int, yellowcard: Int, redcard: Int) -> Endpoint {
        Endpoint(path: "/record/stats", method: .PUT, body: [
            "id": id, "min": min, "goal": goal, "assist": assist,
            "yellowcard": yellowcard, "redcard": redcard
        ])
    }

    static func deleteRecord(id: Int) -> Endpoint {
        Endpoint(path: "/record", method: .DELETE, body: ["id": id])
    }
}

// MARK: - Injury

extension Endpoint {
    /// 팀 전체 부상 이력. 복귀일(returndate)이 빈 값이면 현재 부상 중.
    static func injuries(teamId: Int) -> Endpoint {
        Endpoint(path: "/injury?team=\(teamId)", method: .GET)
    }

    static func createInjury(playerId: Int, type: String, startdate: String, returndate: String, memo: String) -> Endpoint {
        Endpoint(path: "/injury", method: .POST, body: [
            "player": playerId, "type": type, "startdate": startdate,
            "returndate": returndate, "memo": memo
        ])
    }

    static func updateInjury(id: Int, playerId: Int, type: String, startdate: String, returndate: String, memo: String) -> Endpoint {
        // 항상 모든 필드를 보내 빈 값(복귀일 지움 등)이 백엔드 NULL로 반영되게 한다.
        Endpoint(path: "/injury", method: .PUT, body: [
            "id": id, "player": playerId, "type": type, "startdate": startdate,
            "returndate": returndate, "memo": memo
        ])
    }

    static func deleteInjury(id: Int) -> Endpoint {
        Endpoint(path: "/injury", method: .DELETE, body: ["id": id])
    }
}

// MARK: - Training

extension Endpoint {
    /// 팀 전체 훈련 세션 목록.
    static func trainings(teamId: Int) -> Endpoint {
        Endpoint(path: "/training?team=\(teamId)", method: .GET)
    }

    static func createTraining(teamId: Int, trainingdate: String) -> Endpoint {
        Endpoint(path: "/training", method: .POST, body: [
            "team": teamId, "trainingdate": trainingdate
        ])
    }

    static func updateTraining(id: Int, teamId: Int, trainingdate: String) -> Endpoint {
        Endpoint(path: "/training", method: .PUT, body: [
            "id": id, "team": teamId, "trainingdate": trainingdate
        ])
    }

    static func deleteTraining(id: Int) -> Endpoint {
        Endpoint(path: "/training", method: .DELETE, body: ["id": id])
    }
}

// MARK: - Attendance

extension Endpoint {
    /// 팀 전체 참석 목록 — 세션별 그룹핑·선수별 집계는 클라이언트에서 한다.
    static func attendances(teamId: Int) -> Endpoint {
        Endpoint(path: "/attendance?team=\(teamId)", method: .GET)
    }

    /// (training, player)는 UNIQUE — 서버가 upsert 하므로 재전송 시 min만 갱신된다.
    static func upsertAttendances(trainingId: Int, entries: [(player: Int, min: Int)]) -> Endpoint {
        Endpoint(path: "/attendance/batch", method: .POST, arrayBody: entries.map {
            ["training": trainingId, "player": $0.player, "min": $0.min]
        })
    }

    static func deleteAttendances(ids: [Int]) -> Endpoint {
        Endpoint(path: "/attendance/batch", method: .DELETE, arrayBody: ids.map { ["id": $0] })
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

// MARK: - Report (xlsx 다운로드)

extension Endpoint {
    /// 경기기록표 xlsx. 집계·서식은 백엔드가 담당(웹과 동일 파일).
    /// start/end 는 "yyyy-MM-dd"(inclusive), 비우면 전체 기간.
    static func matchRecordReport(teamId: Int, start: String?, end: String?) -> Endpoint {
        var path = "/report/matchrecord?team=\(teamId)"
        if let start, !start.isEmpty { path += "&start=\(start)" }
        if let end, !end.isEmpty { path += "&end=\(end)" }
        return Endpoint(path: path, method: .GET)
    }
}
