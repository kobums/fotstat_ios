import Foundation
import Combine

final class AuthManager: ObservableObject {
    static let shared = AuthManager()
    private init() {
        token = UserDefaults.standard.string(forKey: "auth_token")
    }

    @Published var isLoggedIn: Bool = false
    @Published var currentUser: User?

    private(set) var token: String? {
        didSet {
            isLoggedIn = token != nil
            UserDefaults.standard.set(token, forKey: "auth_token")
        }
    }

    func save(token: String, user: User) {
        self.token = token
        self.currentUser = user
    }

    func logout() {
        self.token = nil
        self.currentUser = nil
    }
}
