import SwiftUI

// 게스트 → 정식 계정 업그레이드. 같은 계정을 그대로 승격하므로
// 그동안 기록한 팀·경기·선수·기록 데이터가 모두 유지됩니다.
struct UpgradeAccountView: View {
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

                Text("계정을 만들고\n데이터를 지키세요.")
                    .font(.system(size: 32, weight: .black))
                    .foregroundColor(t.text)
                    .lineSpacing(2)
                    .padding(.bottom, 8)

                Text("지금까지 기록한 팀과 경기는 그대로 유지됩니다.")
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

                    Button {
                        Task {
                            if await vm.upgradeAccount() { dismiss() }
                        }
                    } label: {
                        ZStack {
                            if vm.isLoading { ProgressView().tint(.white) }
                            else { Text("가입하고 데이터 지키기").font(.system(size: 16, weight: .bold)) }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity).frame(height: 52)
                        .background(t.accent).cornerRadius(14)
                        .shadow(color: t.accent.opacity(0.3), radius: 8, x: 0, y: 4)
                    }
                    .disabled(vm.isLoading).padding(.top, 6)
                }

                Spacer()
            }
            .padding(.horizontal, 28)
        }
    }
}
