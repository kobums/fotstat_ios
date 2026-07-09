import SwiftUI

struct LoginView: View {
    @StateObject private var vm = AuthViewModel()
    @State private var showRegister = false
    @Environment(\.fsTheme) var t

    var body: some View {
        ZStack {
            t.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                Spacer()

                // 로고
                HStack(spacing: 10) {
                    RoundedRectangle(cornerRadius: 9)
                        .fill(t.accent)
                        .frame(width: 36, height: 36)
                        .overlay(Text("F").font(.system(size: 18, weight: .black)).foregroundColor(.white))
                    Text("fotstat")
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(t.text)
                }
                .padding(.bottom, 28)

                Text("다시 만나서\n반갑습니다.")
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(t.text)
                    .lineSpacing(2)
                    .padding(.bottom, 8)

                Text("계정에 로그인해서 팀을 관리하세요.")
                    .font(.system(size: 14))
                    .foregroundColor(t.textSec)
                    .padding(.bottom, 32)

                // 폼
                VStack(spacing: 14) {
                    FSField(label: "이메일", placeholder: "coach@fotstat.app", text: $vm.email)
                        .keyboardType(.emailAddress)
                    FSField(label: "비밀번호", placeholder: "••••••••", text: $vm.password, isSecure: true)

                    if let error = vm.errorMessage {
                        Text(error).font(.system(size: 13)).foregroundColor(t.neg)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    FSPrimaryButton(title: "로그인", isLoading: vm.isLoading) {
                        Task { await vm.login() }
                    }
                }

                // 구분선
                HStack(spacing: 12) {
                    Rectangle().fill(t.line).frame(height: 0.5)
                    Text("또는").font(.system(size: 12)).foregroundColor(t.textTer)
                    Rectangle().fill(t.line).frame(height: 0.5)
                }
                .padding(.vertical, 20)

                // Apple 로그인
                Button {
                    vm.appleCoordinator.onCompletion = { result in
                        Task {
                            if case .success(let cred) = result {
                                await vm.loginWithApple(identityToken: cred.identityToken, authorizationCode: cred.authorizationCode, name: cred.name)
                            }
                        }
                    }
                    vm.appleCoordinator.signIn()
                } label: {
                    HStack(spacing: 8) {
                        Image(systemName: "apple.logo").font(.system(size: 16, weight: .medium))
                        Text("Apple로 계속하기").font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(t.text)
                    .frame(maxWidth: .infinity).frame(height: 48)
                    .background(t.bgElev).cornerRadius(14)
                    .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.lineStrong, lineWidth: 0.5))
                }

                // 게스트 둘러보기 (로그인 없이 앱 사용)
                Button { Task { await vm.continueAsGuest() } } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.right.circle").font(.system(size: 15, weight: .medium))
                        Text("로그인 없이 둘러보기").font(.system(size: 15, weight: .semibold))
                    }
                    .foregroundColor(t.textSec)
                    .frame(maxWidth: .infinity).frame(height: 48)
                }
                .disabled(vm.isLoading)
                .padding(.top, 10)

                Spacer()

                Button { showRegister = true } label: {
                    HStack(spacing: 4) {
                        Text("아직 계정이 없으신가요?").foregroundColor(t.textSec)
                        Text("회원가입").foregroundColor(t.accent).fontWeight(.bold)
                    }
                    .font(.system(size: 13))
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 28)
        }
        .sheet(isPresented: $showRegister) {
            RegisterView().environment(\.fsTheme, t)
        }
    }
}

// MARK: - FSField

struct FSField: View {
    let label: String
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    @Environment(\.fsTheme) var t

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.system(size: 12, weight: .semibold)).foregroundColor(t.textSec)
            ZStack {
                RoundedRectangle(cornerRadius: 12).fill(t.bgElev)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.line, lineWidth: 0.5))
                Group {
                    if isSecure { SecureField(placeholder, text: $text) }
                    else { TextField(placeholder, text: $text) }
                }
                .font(.system(size: 15)).foregroundColor(t.text)
                .autocorrectionDisabled().textInputAutocapitalization(.never)
                .padding(.horizontal, 14)
            }
            .frame(height: 50)
        }
    }
}
