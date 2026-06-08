import AuthenticationServices
import UIKit

final class AppleSignInCoordinator: NSObject,
    ASAuthorizationControllerDelegate,
    ASAuthorizationControllerPresentationContextProviding {

    var onCompletion: (Result<(identityToken: String, authorizationCode: String, name: String), Error>) -> Void = { _ in }

    func signIn() {
        let request = ASAuthorizationAppleIDProvider().createRequest()
        request.requestedScopes = [.fullName, .email]

        let controller = ASAuthorizationController(authorizationRequests: [request])
        controller.delegate = self
        controller.presentationContextProvider = self
        controller.performRequests()
    }

    func presentationAnchor(for controller: ASAuthorizationController) -> ASPresentationAnchor {
        UIApplication.shared.connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap { $0.windows }
            .first { $0.isKeyWindow } ?? UIWindow()
    }

    func authorizationController(controller: ASAuthorizationController,
                                  didCompleteWithAuthorization authorization: ASAuthorization) {
        guard let cred = authorization.credential as? ASAuthorizationAppleIDCredential,
              let tokenData = cred.identityToken,
              let token = String(data: tokenData, encoding: .utf8) else {
            onCompletion(.failure(APIError.unknown(URLError(.badServerResponse))))
            return
        }

        // 한국식 이름 표기: 성(familyName) + 이름(givenName), 공백 없이
        let name = [cred.fullName?.familyName, cred.fullName?.givenName]
            .compactMap { $0 }
            .joined()

        // authorizationCode는 서버에서 refresh token으로 교환해 계정 삭제 시 폐기에 사용
        let authCode = cred.authorizationCode.flatMap { String(data: $0, encoding: .utf8) } ?? ""

        onCompletion(.success((identityToken: token, authorizationCode: authCode, name: name)))
    }

    func authorizationController(controller: ASAuthorizationController,
                                  didCompleteWithError error: Error) {
        if let err = error as? ASAuthorizationError, err.code == .canceled { return }
        onCompletion(.failure(error))
    }
}
