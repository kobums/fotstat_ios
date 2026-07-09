import SwiftUI

struct RegisterView: View {
    @StateObject private var vm = AuthViewModel()
    @Environment(\.dismiss) private var dismiss
    @Environment(\.fsTheme) var t

    var body: some View {
        ZStack {
            t.bg.ignoresSafeArea()

            VStack(alignment: .leading, spacing: 0) {
                // 네비 헤더
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.system(size: 16, weight: .medium))
                            .foregroundColor(t.textSec)
                            .frame(width: 32, height: 32)
                            .background(t.bgElev3).cornerRadius(16)
                    }
                    Spacer()
                }
                .padding(.top, 20).padding(.bottom, 32)

                Text("팀의 모든 경기를\n기록하세요.")
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(t.text)
                    .lineSpacing(2)
                    .padding(.bottom, 8)

                Text("계정을 만들고 첫 팀을 등록하세요.")
                    .font(.system(size: 14))
                    .foregroundColor(t.textSec)
                    .padding(.bottom, 32)

                VStack(spacing: 14) {
                    FSField(label: "닉네임", placeholder: "홍감독", text: $vm.name)
                    FSField(label: "이메일", placeholder: "coach@fotstat.app", text: $vm.email)
                        .keyboardType(.emailAddress)
                    FSField(label: "비밀번호", placeholder: "••••••••", text: $vm.password, isSecure: true)

                    if let error = vm.errorMessage {
                        Text(error).font(.system(size: 13)).foregroundColor(t.neg)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    FSPrimaryButton(title: "계정 만들기", isLoading: vm.isLoading) {
                        Task { await vm.register() }
                    }
                }

                Spacer()

                Button { dismiss() } label: {
                    HStack(spacing: 4) {
                        Text("이미 계정이 있으신가요?").foregroundColor(t.textSec)
                        Text("로그인").foregroundColor(t.accent).fontWeight(.bold)
                    }
                    .font(.system(size: 13))
                }
                .frame(maxWidth: .infinity)
                .padding(.bottom, 32)
            }
            .padding(.horizontal, 28)
        }
    }
}
