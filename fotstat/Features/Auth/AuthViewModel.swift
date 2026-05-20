import Foundation
import Combine

@MainActor
final class AuthViewModel: ObservableObject {
    @Published var email = ""
    @Published var password = ""
    @Published var name = ""
    @Published var isLoading = false
    @Published var errorMessage: String?

    let appleCoordinator = AppleSignInCoordinator()

    func login() async {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "이메일과 비밀번호를 입력해주세요."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await APIClient.shared.request(
                .login(email: email, passwd: password),
                responseType: AuthResponse.self
            )
            guard response.code == "ok", let token = response.token, let user = response.user else {
                errorMessage = response.message ?? "로그인에 실패했습니다."
                return
            }
            AuthManager.shared.save(token: token, user: user)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loginWithApple(identityToken: String, name: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await APIClient.shared.request(
                .appleLogin(identityToken: identityToken, name: name),
                responseType: AuthResponse.self
            )
            guard response.code == "ok", let token = response.token, let user = response.user else {
                errorMessage = response.message ?? "Apple 로그인에 실패했습니다."
                return
            }
            AuthManager.shared.save(token: token, user: user)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func register() async {
        guard !email.isEmpty, !password.isEmpty, !name.isEmpty else {
            errorMessage = "모든 항목을 입력해주세요."
            return
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await APIClient.shared.request(
                .register(email: email, password: password, name: name),
                responseType: CodeResponse.self
            )
            guard response.code == "ok" else {
                errorMessage = "회원가입에 실패했습니다."
                return
            }
            await login()
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}
