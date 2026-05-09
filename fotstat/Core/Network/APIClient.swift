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

final class APIClient {
    static let shared = APIClient()
    private init() {}

    private let baseURL = "http://10.0.1.14:8007/api"

    func request<T: Decodable>(
        _ endpoint: Endpoint,
        responseType: T.Type
    ) async throws -> T {
        guard let url = URL(string: baseURL + endpoint.path) else {
            throw APIError.invalidURL
        }

        var req = URLRequest(url: url)
        req.httpMethod = endpoint.method.rawValue
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")

        if let token = AuthManager.shared.token {
            req.setValue("Bearer \(token)", forHTTPHeaderField: "Authorization")
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
            AuthManager.shared.logout()
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
