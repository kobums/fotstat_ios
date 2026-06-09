import Foundation
import Combine

final class AuthManager: ObservableObject {
    static let shared = AuthManager()
    private init() {
        token = UserDefaults.standard.string(forKey: "auth_token")
        isGuest = UserDefaults.standard.bool(forKey: "auth_is_guest")
    }

    @Published var isLoggedIn: Bool = false
    @Published var currentUser: User?

    /// True when the current session is an anonymous guest account (no personal
    /// info provided). Used to surface a "register to keep your data" prompt.
    @Published private(set) var isGuest: Bool = false {
        didSet { UserDefaults.standard.set(isGuest, forKey: "auth_is_guest") }
    }

    private(set) var token: String? {
        didSet {
            isLoggedIn = token != nil
            UserDefaults.standard.set(token, forKey: "auth_token")
        }
    }

    func save(token: String, user: User, isGuest: Bool = false) {
        self.token = token
        self.currentUser = user
        self.isGuest = isGuest
    }

    func logout() {
        self.token = nil
        self.currentUser = nil
        self.isGuest = false
    }
}
