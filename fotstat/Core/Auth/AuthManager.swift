import Foundation
import Combine

final class AuthManager: ObservableObject {
    static let shared = AuthManager()

    // Keychain account keys for the stored credentials.
    private static let accessKey = "access_token"
    private static let refreshKey = "refresh_token"
    // Legacy UserDefaults key used before tokens moved to the Keychain.
    private static let legacyTokenKey = "auth_token"

    private init() {
        // Migrate a token left in UserDefaults by older builds into the Keychain.
        if KeychainStore.get(Self.accessKey) == nil,
           let legacy = UserDefaults.standard.string(forKey: Self.legacyTokenKey) {
            KeychainStore.set(legacy, for: Self.accessKey)
            UserDefaults.standard.removeObject(forKey: Self.legacyTokenKey)
        }

        token = KeychainStore.get(Self.accessKey)
        refreshToken = KeychainStore.get(Self.refreshKey)
        isGuest = UserDefaults.standard.bool(forKey: "auth_is_guest")
        isLoggedIn = token != nil
        // The user object isn't persisted separately, so on auto-login restore
        // it from the JWT payload (it embeds id/email/name). Without this,
        // currentUser stays nil after a cold start and screens that key off
        // currentUser?.id silently do nothing.
        currentUser = token.flatMap(Self.user(fromJWT:))
    }

    @Published var isLoggedIn: Bool = false
    @Published var currentUser: User?

    /// True when the current session is an anonymous guest account (no personal
    /// info provided). Used to surface a "register to keep your data" prompt.
    @Published private(set) var isGuest: Bool = false {
        didSet { UserDefaults.standard.set(isGuest, forKey: "auth_is_guest") }
    }

    /// Short-lived access JWT attached to API requests.
    private(set) var token: String? {
        didSet { KeychainStore.set(token, for: Self.accessKey) }
    }

    /// Long-lived refresh token used to silently renew `token` when it expires.
    private(set) var refreshToken: String? {
        didSet { KeychainStore.set(refreshToken, for: Self.refreshKey) }
    }

    func save(token: String, refresh: String?, user: User, isGuest: Bool = false) {
        self.token = token
        self.refreshToken = refresh
        self.currentUser = user
        self.isGuest = isGuest
        self.isLoggedIn = true
    }

    /// Apply a renewed session from the /refresh endpoint, keeping the existing
    /// guest flag. `refresh` is non-rotating server-side but echoed back, so we
    /// persist whatever the server returns.
    func updateAfterRefresh(token: String, refresh: String?, user: User?) {
        self.token = token
        if let refresh { self.refreshToken = refresh }
        if let user { self.currentUser = user }
        self.isLoggedIn = true
    }

    func logout() {
        self.token = nil
        self.refreshToken = nil
        self.currentUser = nil
        self.isGuest = false
        self.isLoggedIn = false
    }

    /// Reconstructs the signed-in user from a JWT's payload. The backend embeds
    /// the user under a "user" claim; we only read it (no signature check) to
    /// repopulate `currentUser` on launch. Returns nil for a malformed token.
    private static func user(fromJWT token: String) -> User? {
        let segments = token.split(separator: ".")
        guard segments.count == 3 else { return nil }

        var base64 = String(segments[1])
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }

        guard let data = Data(base64Encoded: base64) else { return nil }

        struct Payload: Decodable { let user: User }
        return try? JSONDecoder().decode(Payload.self, from: data).user
    }
}
