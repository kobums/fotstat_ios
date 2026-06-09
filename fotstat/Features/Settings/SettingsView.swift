import SwiftUI

struct SettingsView: View {
    @AppStorage("themePreference") var themePreference: String = "system"
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.fsTheme) var t
    @Environment(\.dismiss) var dismiss

    private var user: User? { authManager.currentUser }

    @State private var showDeleteConfirm = false
    @State private var isDeleting = false
    @State private var deleteError: String?
    @State private var showUpgrade = false

    private let themeOptions: [(label: String, icon: String, value: String)] = [
        ("시스템", "circle.lefthalf.filled", "system"),
        ("라이트", "sun.max", "light"),
        ("다크", "moon", "dark"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            // 핸들
            Capsule().fill(t.textTer).frame(width: 36, height: 4)
                .padding(.top, 12).padding(.bottom, 24)

            ScrollView {
                VStack(spacing: 20) {
                    // 프로필 카드
                    HStack(spacing: 14) {
                        ZStack {
                            Circle().fill(t.accent.opacity(0.15))
                                .frame(width: 52, height: 52)
                            Text(user?.name.prefix(1).uppercased() ?? "?")
                                .font(.system(size: 22, weight: .black))
                                .foregroundColor(t.accent)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text(user?.name ?? "—")
                                .font(.system(size: 17, weight: .bold))
                                .foregroundColor(t.text)
                            Text(authManager.isGuest ? "게스트 모드" : (user?.email ?? "—"))
                                .font(.system(size: 13))
                                .foregroundColor(t.textSec)
                        }
                        Spacer()
                    }
                    .padding(16)
                    .background(t.bgElev)
                    .cornerRadius(16)
                    .overlay(RoundedRectangle(cornerRadius: 16).stroke(t.line, lineWidth: 0.5))
                    .padding(.horizontal, 20)

                    // 게스트 → 가입 유도 배너
                    if authManager.isGuest {
                        Button { showUpgrade = true } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "person.crop.circle.badge.plus")
                                    .font(.system(size: 22))
                                    .foregroundColor(t.accent)
                                VStack(alignment: .leading, spacing: 3) {
                                    Text("계정 만들기")
                                        .font(.system(size: 15, weight: .bold))
                                        .foregroundColor(t.text)
                                    Text("가입하면 지금 기록이 안전하게 보관됩니다")
                                        .font(.system(size: 12))
                                        .foregroundColor(t.textSec)
                                        .multilineTextAlignment(.leading)
                                }
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(t.textTer)
                            }
                            .padding(16)
                            .background(t.accentSoft)
                            .cornerRadius(16)
                            .overlay(RoundedRectangle(cornerRadius: 16).stroke(t.accent.opacity(0.3), lineWidth: 0.5))
                        }
                        .padding(.horizontal, 20)
                    }

                    // 외관 섹션
                    VStack(alignment: .leading, spacing: 10) {
                        Text("외관")
                            .font(.system(size: 11, weight: .bold))
                            .kerning(0.6)
                            .foregroundColor(t.textTer)
                            .padding(.leading, 4)

                        HStack(spacing: 8) {
                            ForEach(themeOptions, id: \.value) { opt in
                                Button {
                                    themePreference = opt.value
                                } label: {
                                    VStack(spacing: 8) {
                                        Image(systemName: opt.icon)
                                            .font(.system(size: 18))
                                            .foregroundColor(themePreference == opt.value ? .white : t.textSec)
                                            .frame(width: 44, height: 44)
                                            .background(themePreference == opt.value ? t.accent : t.bgElev3)
                                            .clipShape(Circle())
                                        Text(opt.label)
                                            .font(.system(size: 11, weight: .semibold))
                                            .foregroundColor(themePreference == opt.value ? t.accent : t.textSec)
                                    }
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 14)
                                    .background(themePreference == opt.value ? t.accentSoft : t.bgElev)
                                    .cornerRadius(14)
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 14)
                                            .stroke(themePreference == opt.value ? t.accent.opacity(0.4) : t.line, lineWidth: 0.5)
                                    )
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 20)

                    // 앱 정보 섹션
                    VStack(alignment: .leading, spacing: 10) {
                        Text("앱 정보")
                            .font(.system(size: 11, weight: .bold))
                            .kerning(0.6)
                            .foregroundColor(t.textTer)
                            .padding(.leading, 4)

                        VStack(spacing: 0) {
                            infoRow(label: "버전", value: Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "—")
                        }
                        .background(t.bgElev)
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.line, lineWidth: 0.5))
                    }
                    .padding(.horizontal, 20)

                    // 로그아웃
                    Button {
                        authManager.logout()
                        dismiss()
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                                .font(.system(size: 15, weight: .semibold))
                            Text("로그아웃")
                                .font(.system(size: 15, weight: .semibold))
                        }
                        .foregroundColor(t.neg)
                        .frame(maxWidth: .infinity)
                        .frame(height: 52)
                        .background(t.neg.opacity(0.08))
                        .cornerRadius(14)
                        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.neg.opacity(0.2), lineWidth: 0.5))
                    }
                    .padding(.horizontal, 20)
                    .padding(.top, 4)

                    // 계정 삭제
                    Button {
                        showDeleteConfirm = true
                    } label: {
                        HStack(spacing: 6) {
                            if isDeleting {
                                ProgressView()
                            } else {
                                Image(systemName: "trash")
                                    .font(.system(size: 13, weight: .semibold))
                            }
                            Text("계정 삭제")
                                .font(.system(size: 14, weight: .semibold))
                        }
                        .foregroundColor(t.textSec)
                        .frame(maxWidth: .infinity)
                        .frame(height: 46)
                    }
                    .disabled(isDeleting)
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
            }
        }
        .background(t.bg.ignoresSafeArea())
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.hidden)
        .sheet(isPresented: $showUpgrade) {
            UpgradeAccountView().environment(\.fsTheme, t)
        }
        .alert("계정을 삭제할까요?", isPresented: $showDeleteConfirm) {
            Button("취소", role: .cancel) {}
            Button("삭제", role: .destructive) {
                Task { await deleteAccount() }
            }
        } message: {
            Text("계정과 모든 팀·경기·선수·기록 데이터가 영구적으로 삭제되며 복구할 수 없습니다.")
        }
        .alert("삭제 실패", isPresented: Binding(
            get: { deleteError != nil },
            set: { if !$0 { deleteError = nil } }
        )) {
            Button("확인", role: .cancel) { deleteError = nil }
        } message: {
            Text(deleteError ?? "")
        }
    }

    private func deleteAccount() async {
        isDeleting = true
        defer { isDeleting = false }
        do {
            let response = try await APIClient.shared.request(
                .deleteAccount(),
                responseType: CodeResponse.self
            )
            guard response.code == "ok" else {
                deleteError = "계정 삭제에 실패했습니다."
                return
            }
            authManager.logout()
            dismiss()
        } catch {
            deleteError = error.localizedDescription
        }
    }

    @ViewBuilder
    private func infoRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .font(.system(size: 14, weight: .medium))
                .foregroundColor(t.text)
            Spacer()
            Text(value)
                .font(.system(size: 14))
                .foregroundColor(t.textSec)
        }
        .padding(.horizontal, 16).padding(.vertical, 13)
    }
}
