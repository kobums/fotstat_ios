import SwiftUI

// MARK: - HomeView (팀 목록 / 앱 홈)

struct HomeView: View {
    @StateObject private var vm = TeamViewModel()
    @State private var showAddTeam = false
    @State private var newTeamName = ""
    @State private var teamToRename: Team?
    @State private var renameTeamName = ""
    @State private var teamToSetDuration: Team?
    @State private var durationText = ""
    @State private var teamToDelete: Team?
    @State private var showSettings = false
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
                            Spacer()
                            Button(action: { showSettings = true }) {
                                Image(systemName: "ellipsis")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(t.text)
                                    .frame(width: 36, height: 36)
                            }
                            .glassEffect(.regular.interactive(), in: Circle())
                        }
                        .padding(.horizontal, 16)
                        .padding(.top, 60)
                        .padding(.bottom, 16)

                        if vm.isLoading {
                            ProgressView().frame(maxWidth: .infinity).padding(.top, 80)
                        } else if vm.teams.isEmpty {
                            emptyView
                        } else {
                            VStack(spacing: 8) {
                                ForEach(vm.teams) { team in
                                    NavigationLink(value: team) {
                                        TeamRow(team: team)
                                    }
                                    .buttonStyle(.plain)
                                    .contextMenu {
                                        Button {
                                            renameTeamName = team.name
                                            teamToRename = team
                                        } label: {
                                            Label("이름 수정", systemImage: "pencil")
                                        }
                                        Button {
                                            durationText = "\(team.duration ?? 45)"
                                            teamToSetDuration = team
                                        } label: {
                                            Label("쿼터 기본 시간", systemImage: "clock")
                                        }
                                        Button(role: .destructive) {
                                            teamToDelete = team
                                        } label: {
                                            Label("팀 삭제", systemImage: "trash")
                                        }
                                        .disabled(vm.deletingTeamIds.contains(team.id))
                                    }
                                }
                            }
                            .padding(.horizontal, 16)
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
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(\.fsTheme, t)
        }
        .alert("팀 추가", isPresented: $showAddTeam) {
            TextField("팀 이름", text: $newTeamName)
            Button("추가") {
                guard !newTeamName.isEmpty else { return }
                Task { await vm.createTeam(name: newTeamName); newTeamName = "" }
            }
            Button("취소", role: .cancel) { newTeamName = "" }
        }
        .alert(
            "이름 수정",
            isPresented: Binding(
                get: { teamToRename != nil },
                set: { if !$0 { teamToRename = nil } }
            ),
            presenting: teamToRename
        ) { team in
            TextField("팀 이름", text: $renameTeamName)
            Button("저장") {
                let name = renameTeamName.trimmingCharacters(in: .whitespaces)
                guard !name.isEmpty else { return }
                // updateTeam 이 성공 시 목록을 다시 불러온다
                Task { await vm.updateTeam(id: team.id, name: name); renameTeamName = "" }
            }
            Button("취소", role: .cancel) { renameTeamName = "" }
        }
        .alert(
            "쿼터 기본 시간",
            isPresented: Binding(
                get: { teamToSetDuration != nil },
                set: { if !$0 { teamToSetDuration = nil } }
            ),
            presenting: teamToSetDuration
        ) { team in
            TextField("분", text: $durationText)
                .keyboardType(.numberPad)
            Button("저장") {
                // 쿼터 추가 시트와 동일한 1~120분 범위로 보정
                let minutes = min(120, max(1, Int(durationText.filter(\.isNumber)) ?? 45))
                Task { await vm.updateTeam(id: team.id, name: team.name, duration: minutes); durationText = "" }
            }
            Button("취소", role: .cancel) { durationText = "" }
        } message: { _ in
            Text("경기에 쿼터를 추가할 때 이 시간이 기본으로 표시됩니다. (1~120분)")
        }
        .confirmationDialog(
            "팀 삭제",
            isPresented: Binding(
                get: { teamToDelete != nil },
                set: { if !$0 { teamToDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: teamToDelete
        ) { team in
            Button("삭제", role: .destructive) {
                Task { await vm.deleteTeam(id: team.id) }
            }
            Button("취소", role: .cancel) {}
        } message: { team in
            Text("'\(team.name)' 팀과 소속 선수·경기·기록·부상 내역이 모두 삭제됩니다. 이 작업은 되돌릴 수 없습니다.")
        }
        .alert(
            "오류",
            isPresented: Binding(get: { vm.errorMessage != nil }, set: { if !$0 { vm.errorMessage = nil } })
        ) {
            Button("확인", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
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

// MARK: - TeamRow

struct TeamRow: View {
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
