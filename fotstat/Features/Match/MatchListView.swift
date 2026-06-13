import SwiftUI

struct MatchListView: View {
    @StateObject private var vm: MatchViewModel
    @State private var showAddMatch = false
    @State private var pendingDelete: Match?
    @State private var openSwipeID: Int?
    @Environment(\.fsTheme) var t

    init(team: Team) {
        _vm = StateObject(wrappedValue: MatchViewModel(team: team))
    }

    private var upcoming: [Match] {
        vm.matches
            .filter { ($0.parsedDate ?? .distantPast) > Date() }
            .sorted { ($0.parsedDate ?? .distantPast) < ($1.parsedDate ?? .distantPast) }
    }

    private var finished: [Match] {
        vm.matches
            .filter { ($0.parsedDate ?? .distantPast) <= Date() }
            .sorted { ($0.parsedDate ?? .distantPast) > ($1.parsedDate ?? .distantPast) }
    }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    FSTeamHeader(team: vm.team, tab: .matches)

                    if vm.isLoading {
                        ProgressView().padding(.top, 80)
                    } else {
                        // 예정 경기
                        FSSectionHeader(title: "예정 경기")
                        if upcoming.isEmpty {
                            Text("예정된 경기가 없습니다")
                                .font(.system(size: 13))
                                .foregroundColor(t.textSec)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 16)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(upcoming.enumerated()), id: \.element.id) { i, match in
                                    FSSwipeToDelete(id: match.id, openID: $openSwipeID) {
                                        NavigationLink(value: match) {
                                            MatchRow(match: match, teamName: vm.team.name, isUpcoming: true)
                                        }
                                        .buttonStyle(.plain)
                                    } onDelete: {
                                        pendingDelete = match
                                    }
                                    if i < upcoming.count - 1 {
                                        Divider().background(t.line)
                                    }
                                }
                            }
                            .background(t.bgElev)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.line, lineWidth: 0.5))
                            .padding(.horizontal, 16)
                        }

                        // 완료 경기
                        HStack {
                            FSSectionHeader(title: "완료 경기")
                            Spacer()
                        }

                        if finished.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "soccerball").font(.system(size: 40)).foregroundColor(t.textTer)
                                Text("경기 기록이 없습니다").font(.system(size: 15)).foregroundColor(t.textSec)
                            }
                            .frame(maxWidth: .infinity).padding(.top, 40)
                        } else {
                            VStack(spacing: 0) {
                                ForEach(Array(finished.enumerated()), id: \.element.id) { i, match in
                                    FSSwipeToDelete(id: match.id, openID: $openSwipeID) {
                                        NavigationLink(value: match) {
                                            MatchRow(match: match, teamName: vm.team.name)
                                        }
                                        .buttonStyle(.plain)
                                    } onDelete: {
                                        pendingDelete = match
                                    }
                                    if i < finished.count - 1 {
                                        Divider().background(t.line)
                                    }
                                }
                            }
                            .background(t.bgElev)
                            .cornerRadius(12)
                            .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.line, lineWidth: 0.5))
                            .padding(.horizontal, 16)
                        }

                    }
                }
                .padding(.bottom, 100)
            }

            // FAB
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button { showAddMatch = true } label: {
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
        .background(t.bg.ignoresSafeArea())
        .task { await vm.fetchMatches() }
        .sheet(isPresented: $showAddMatch) {
            MatchFormView { awayName, matchDate in
                Task { await vm.createMatch(awayName: awayName, matchDate: matchDate) }
            }
            .environment(\.fsTheme, t)
        }
        .confirmationDialog(
            "경기 삭제",
            isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                if let match = pendingDelete {
                    Task { await vm.deleteMatch(id: match.id) }
                }
                pendingDelete = nil
            }
            Button("취소", role: .cancel) { pendingDelete = nil }
        } message: {
            if let match = pendingDelete {
                Text("'\(match.awayname)' 경기를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.")
            }
        }
    }
}

// MARK: - MatchRow

struct MatchRow: View {
    let match: Match
    let teamName: String
    var isUpcoming: Bool = false
    @Environment(\.fsTheme) var t

    private var displayDate: String {
        guard let d = match.parsedDate else { return "" }
        let f = DateFormatter(); f.dateFormat = "MM/dd"
        return f.string(from: d)
    }

    private var displayTime: String {
        guard let d = match.parsedDate else { return "" }
        let f = DateFormatter(); f.dateFormat = "HH:mm"
        return f.string(from: d)
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(spacing: 1) {
                Text(displayDate).font(.system(size: 9, weight: .bold)).foregroundColor(t.textTer)
                Text(displayTime).font(.system(size: 9)).foregroundColor(t.textTer)
            }
            .frame(width: 34)

            FSCrest(name: teamName, size: 22, radius: 5)

            VStack(alignment: .leading, spacing: 0) {
                Text(teamName).font(.system(size: 12, weight: .semibold)).foregroundColor(t.text)
                Text(match.awayname).font(.system(size: 12, weight: .semibold)).foregroundColor(t.text)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            FSCrest(name: match.awayname, size: 22, radius: 5)

            if isUpcoming {
                Text("예정")
                    .font(.system(size: 11, weight: .bold)).kerning(0.4)
                    .foregroundColor(t.accent)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(t.accentSoft).cornerRadius(6)
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(t.textTer)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
    }
}
