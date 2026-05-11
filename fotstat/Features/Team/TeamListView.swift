import SwiftUI

// MARK: - HomeView (팀 목록 / 앱 홈)

struct HomeView: View {
    @StateObject private var vm = TeamViewModel()
    @State private var showAddTeam = false
    @State private var newTeamName = ""
    @Environment(\.fsTheme) var t

    var body: some View {
        NavigationStack {
            ZStack {
                ScrollView {
                    VStack(alignment: .leading, spacing: 0) {
                        // 헤더
                        HStack(alignment: .bottom) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("안녕하세요")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(t.textSec)
                                Text("내 팀")
                                    .font(.system(size: 32, weight: .black))
                                    .foregroundColor(t.text)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 60)
                        .padding(.bottom, 16)

                        if vm.isLoading {
                            ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
                        } else if vm.teams.isEmpty {
                            emptyView
                        } else {
                            if let main = vm.teams.first {
                                NavigationLink(value: main) {
                                    MainTeamCard(team: main)
                                }
                                .buttonStyle(.plain)
                                .padding(.horizontal, 16)
                                .padding(.bottom, 14)
                            }

                            if vm.teams.count > 1 {
                                HStack {
                                    Text("다른 팀")
                                        .font(.system(size: 13, weight: .bold))
                                        .kerning(0.6)
                                        .textCase(.uppercase)
                                        .foregroundColor(t.textSec)
                                    Spacer()
                                }
                                .padding(.horizontal, 16)
                                .padding(.bottom, 8)

                                VStack(spacing: 8) {
                                    ForEach(vm.teams.dropFirst()) { team in
                                        NavigationLink(value: team) {
                                            OtherTeamRow(team: team)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                                .padding(.horizontal, 16)
                            }
                        }
                    }
                    .padding(.bottom, 100)
                }
                .ignoresSafeArea(edges: .top)

                // FAB
                VStack {
                    Spacer()
                    HStack {
                        Spacer()
                        Button { showAddTeam = true } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 22, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 56, height: 56)
                                .background(t.accent)
                                .clipShape(Circle())
                                .shadow(color: t.accent.opacity(0.4), radius: 12, x: 0, y: 6)
                        }
                        .padding(.trailing, 24)
                        .padding(.bottom, 32)
                    }
                }
            }
            .navigationDestination(for: Team.self) { team in
                TeamContextView(team: team)
            }
            .background(t.bg.ignoresSafeArea())
            .toolbar(.hidden, for: .navigationBar)
        }
        .task { await vm.fetchTeams() }
        .alert("팀 추가", isPresented: $showAddTeam) {
            TextField("팀 이름", text: $newTeamName)
            Button("추가") {
                guard !newTeamName.isEmpty else { return }
                Task { await vm.createTeam(name: newTeamName); newTeamName = "" }
            }
            Button("취소", role: .cancel) { newTeamName = "" }
        }
    }

    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.3").font(.system(size: 48)).foregroundColor(t.textTer)
            Text("팀이 없습니다").font(.system(size: 17, weight: .semibold)).foregroundColor(t.textSec)
            Text("+ 버튼을 눌러 첫 팀을 만드세요").font(.system(size: 13)).foregroundColor(t.textTer)
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 80)
    }
}

// MARK: - MainTeamCard

struct MainTeamCard: View {
    let team: Team
    @Environment(\.fsTheme) var t

    var body: some View {
        HStack(spacing: 14) {
            FSCrest(name: team.name, size: 54, radius: 12)
            VStack(alignment: .leading, spacing: 4) {
                Text(team.name)
                    .font(.system(size: 18, weight: .bold))
                    .foregroundColor(t.text)
                Text("탭하여 팀 관리")
                    .font(.system(size: 12))
                    .foregroundColor(t.textSec)
            }
            Spacer()
            Text("내 팀")
                .font(.system(size: 11, weight: .black))
                .kerning(0.3)
                .foregroundColor(t.accent)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(t.accentSoft).cornerRadius(6)
            Image(systemName: "chevron.right")
                .font(.system(size: 13))
                .foregroundColor(t.textTer)
        }
        .padding(16)
        .background(t.bgElev)
        .cornerRadius(18)
        .overlay(RoundedRectangle(cornerRadius: 18).stroke(t.line, lineWidth: 0.5))
    }
}

// MARK: - OtherTeamRow

struct OtherTeamRow: View {
    let team: Team
    @Environment(\.fsTheme) var t

    var body: some View {
        HStack(spacing: 12) {
            FSCrest(name: team.name, size: 36, radius: 8)
            Text(team.name)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(t.text)
            Spacer()
            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(t.textTer)
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .background(t.bgElev)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.line, lineWidth: 0.5))
    }
}
