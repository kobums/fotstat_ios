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

    /// AuthResponse 처리 공통: 성공(code=="ok" + token + user)이면 세션을 저장하고 true,
    /// 실패면 errorMessage 를 설정하고 false. login/apple/guest/upgrade 가 공유한다.
    private func handleAuthResponse(_ response: AuthResponse, failMessage: String, isGuest: Bool = false) -> Bool {
        guard response.code == "ok", let token = response.token, let user = response.user else {
            errorMessage = response.message ?? failMessage
            return false
        }
        AuthManager.shared.save(token: token, refresh: response.refresh, user: user, isGuest: isGuest)
        return true
    }

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
            _ = handleAuthResponse(response, failMessage: "로그인에 실패했습니다.")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func loginWithApple(identityToken: String, authorizationCode: String, name: String) async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await APIClient.shared.request(
                .appleLogin(identityToken: identityToken, authorizationCode: authorizationCode, name: name),
                responseType: AuthResponse.self
            )
            _ = handleAuthResponse(response, failMessage: "Apple 로그인에 실패했습니다.")
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    func continueAsGuest() async {
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await APIClient.shared.request(
                .guest(),
                responseType: AuthResponse.self
            )
            _ = handleAuthResponse(response, failMessage: "게스트 시작에 실패했습니다.", isGuest: true)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    /// Converts the current guest account into a full account in place,
    /// keeping all data. Returns true on success so the caller can dismiss.
    func upgradeAccount() async -> Bool {
        guard !email.isEmpty, !password.isEmpty else {
            errorMessage = "이메일과 비밀번호를 입력해주세요."
            return false
        }
        isLoading = true
        errorMessage = nil
        defer { isLoading = false }

        do {
            let response = try await APIClient.shared.request(
                .upgradeAccount(email: email, password: password, name: name),
                responseType: AuthResponse.self
            )
            return handleAuthResponse(response, failMessage: "가입에 실패했습니다.", isGuest: false)
        } catch {
            errorMessage = error.localizedDescription
            return false
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
