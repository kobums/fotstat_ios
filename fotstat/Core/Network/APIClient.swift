import Foundation

enum APIError: Error, LocalizedError {
    case invalidURL
    case unauthorized
    case serverError(Int)
    case decodingError
    case unknown(Error)

    var errorDescription: String? {
        switch self {
        case .invalidURL:       return "잘못된 URL입니다."
        case .unauthorized:     return "로그인이 필요합니다."
        case .serverError(let code): return "서버 오류 (\(code))"
        case .decodingError:    return "데이터 파싱 오류"
        case .unknown(let e):   return e.localizedDescription
        }
    }
}

/// Coalesces concurrent token refreshes into a single network call. When many
/// requests get a 401 at once (e.g. on launch with an expired access token),
/// only the first triggers `/refresh`; the rest await the same result.
private actor TokenRefreshCoordinator {
    private var inFlight: Task<Bool, Never>?

    func refresh(_ perform: @escaping () async -> Bool) async -> Bool {
        if let inFlight {
            return await inFlight.value
        }
        let task = Task { await perform() }
        inFlight = task
        // Always clear the slot, even if awaiting is cancelled, so a future 401
        // can start a fresh refresh instead of awaiting a stale task forever.
        defer { inFlight = nil }
        return await task.value
    }
}

final class APIClient {
    static let shared = APIClient()
    private init() {}

    private let baseURL = Config.baseURL
    private let refresher = TokenRefreshCoordinator()

    func request<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type
    ) async throws -> T {
        try await request(endpoint, responseType: responseType, allowRetry: true)
    }

    private func request<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type,
        allowRetry: Bool
    ) async throws -> T {
        guard let url = URL(string: baseURL + endpoint.path) else {
            throw APIError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = endpoint.method.rawValue
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let sentToken = endpoint.requiresAuth ? AuthManager.shared.token : nil
        if let sentToken {
            req.setValue("Bearer \(sentToken)", forHTTPHeaderField: "Authorization")
        }

        if let body = endpoint.body {
            req.httpBody = try JSONSerialization.data(withJSONObject: body)
        }

        let (data, response) = try await URLSession.shared.data(for: req)

        guard let http = response as? HTTPURLResponse else {
            throw APIError.unknown(URLError(.badServerResponse))
        }

        switch http.statusCode {
        case 200...299:
            break
        case 401:
            // The access token expired. Try to silently renew it once with the
            // refresh token, then replay the original request.
            if endpoint.requiresAuth, allowRetry, await renewSession(staleToken: sentToken) {
                return try await request(endpoint, responseType: responseType, allowRetry: false)
            }
            await MainActor.run { AuthManager.shared.logout() }
            throw APIError.unauthorized
        default:
            throw APIError.serverError(http.statusCode)
        }

        do {
            return try JSONDecoder.fotstat.decode(T.self, from: data)
        } catch {
            throw APIError.decodingError
        }
    }

    /// Renews the access token using the stored refresh token. Returns true if a
    /// valid session is now in place. Coalesced so concurrent 401s refresh once.
    private func renewSession(staleToken: String?) async -> Bool {
        await refresher.refresh {
            await Self.performRefresh(staleAccessToken: staleToken)
        }
    }

    private static func performRefresh(staleAccessToken: String?) async -> Bool {
        // AuthManager is MainActor-bound state; read its tokens on the main actor.
        let (currentToken, refreshToken) = await MainActor.run {
            (AuthManager.shared.token, AuthManager.shared.refreshToken)
        }
        // Another request may have already refreshed while this one was queued
        // behind the coordinator.
        if let currentToken, currentToken != staleAccessToken {
            return true
        }
        guard let refreshToken else {
            return false
        }

        let endpoint = Endpoint.refresh(token: refreshToken)
        guard let url = URL(string: Config.baseURL + endpoint.path) else { return false }
        var req = URLRequest(url: url)
        req.httpMethod = endpoint.method.rawValue
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if let body = endpoint.body {
            req.httpBody = try? JSONSerialization.data(withJSONObject: body)
        }

        do {
            let (data, response) = try await URLSession.shared.data(for: req)
            guard let http = response as? HTTPURLResponse, http.statusCode == 200 else {
                return false
            }
            let auth = try JSONDecoder.fotstat.decode(AuthResponse.self, from: data)
            guard auth.code == "ok", let newToken = auth.token else {
                return false
            }
            await MainActor.run {
                AuthManager.shared.updateAfterRefresh(token: newToken, refresh: auth.refresh, user: auth.user)
            }
            return true
        } catch {
            return false
        }
    }
}

// MARK: - JSONDecoder 공통 설정

extension JSONDecoder {
    static let fotstat: JSONDecoder = {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ss"
        decoder.dateDecodingStrategy = .formatted(formatter)
        return decoder
    }()
}
