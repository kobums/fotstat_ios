import SwiftUI

struct MatchListView: View {
    @StateObject private var vm: MatchViewModel
    @State private var showAddMatch = false
    @State private var matchToDelete: Match?
    @Environment(\.fsTheme) var t

    init(team: Team) {
        _vm = StateObject(wrappedValue: MatchViewModel(team: team))
    }

    var body: some View {
        ZStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    FSTeamHeader(team: vm.team, tab: .matches)

                    if vm.isLoading {
                        ProgressView().padding(.top, 80)
                    } else {
                        // 예정 경기 (상단 고정, 가까운 순)
                        if !vm.upcomingMatches.isEmpty {
                            FSSectionHeader(title: "예정 경기")
                            matchCard(vm.upcomingMatches, isUpcoming: true)
                        }

                        // 지난 경기 (월별 그룹 + 무한 스크롤)
                        if vm.monthSections.isEmpty && vm.upcomingMatches.isEmpty {
                            VStack(spacing: 12) {
                                Image(systemName: "soccerball").font(.system(size: 40)).foregroundColor(t.textTer)
                                Text("경기 기록이 없습니다").font(.system(size: 15)).foregroundColor(t.textSec)
                            }
                            .frame(maxWidth: .infinity).padding(.top, 40)
                        } else {
                            ForEach(vm.monthSections) { section in
                                MonthDivider(title: section.title)
                                matchCard(section.matches, isUpcoming: false)
                            }
                        }

                        // 무한 스크롤 트리거 (다음 페이지 로드)
                        if vm.hasMorePast {
                            if vm.pastLoadFailed {
                                Button { Task { await vm.loadMorePast() } } label: {
                                    Text("다시 불러오기")
                                        .font(.system(size: 13, weight: .semibold))
                                        .foregroundColor(t.accent)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 16)
                                }
                            } else {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 20)
                                    .onAppear { Task { await vm.loadMorePast() } }
                            }
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
        .task { await vm.loadInitial() }
        .sheet(isPresented: $showAddMatch) {
            MatchFormView { awayName, matchDate in
                Task { await vm.createMatch(awayName: awayName, matchDate: matchDate) }
            }
            .environment(\.fsTheme, t)
        }
        .onReceive(NotificationCenter.default.publisher(for: .matchDeleted)) { note in
            if let id = note.userInfo?["matchId"] as? Int {
                vm.removeMatch(id: id)
            }
        }
        .confirmationDialog(
            "경기 삭제",
            isPresented: Binding(
                get: { matchToDelete != nil },
                set: { if !$0 { matchToDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: matchToDelete
        ) { match in
            Button("삭제", role: .destructive) {
                Task { await vm.deleteMatch(id: match.id) }
            }
            Button("취소", role: .cancel) {}
        } message: { match in
            Text("'\(match.awayname)' 경기와 모든 쿼터·기록이 삭제됩니다. 이 작업은 되돌릴 수 없습니다.")
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

    // 경기 목록 카드 (예정/지난 공용)
    @ViewBuilder
    private func matchCard(_ matches: [Match], isUpcoming: Bool) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(matches.enumerated()), id: \.element.id) { i, match in
                NavigationLink(value: match) {
                    MatchRow(match: match, score: vm.matchScores[match.id], isUpcoming: isUpcoming)
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        matchToDelete = match
                    } label: {
                        Label("경기 삭제", systemImage: "trash")
                    }
                    .disabled(vm.deletingIds.contains(match.id))
                }
                if i < matches.count - 1 {
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

// MARK: - MonthDivider

struct MonthDivider: View {
    let title: String
    @Environment(\.fsTheme) var t

    var body: some View {
        HStack(spacing: 10) {
            Rectangle().fill(t.line).frame(height: 0.5)
            Text(title)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(t.textSec)
                .fixedSize()
            Rectangle().fill(t.line).frame(height: 0.5)
        }
        .padding(.horizontal, 16)
        .padding(.top, 18).padding(.bottom, 8)
    }
}

// MARK: - MatchRow

struct MatchRow: View {
    let match: Match
    var score: MatchScore? = nil
    var isUpcoming: Bool = false
    @Environment(\.fsTheme) var t

    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "MM/dd"; return f
    }()
    private static let timeFormatter: DateFormatter = {
        let f = DateFormatter(); f.dateFormat = "HH:mm"; return f
    }()

    private var displayDate: String {
        guard let d = match.parsedDate else { return "" }
        return Self.dateFormatter.string(from: d)
    }

    private var displayTime: String {
        guard let d = match.parsedDate else { return "" }
        return Self.timeFormatter.string(from: d)
    }

    var body: some View {
        HStack(spacing: 10) {
            VStack(spacing: 1) {
                Text(displayDate).font(.system(size: 9, weight: .bold)).foregroundColor(t.textTer)
                Text(displayTime).font(.system(size: 9)).foregroundColor(t.textTer)
            }
            .frame(width: 34)

            FSCrest(name: match.awayname, size: 26, radius: 6)

            Text(match.awayname)
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(t.text)
                .lineLimit(1)
                .frame(maxWidth: .infinity, alignment: .leading)

            if isUpcoming {
                Text("예정")
                    .font(.system(size: 11, weight: .bold)).kerning(0.4)
                    .foregroundColor(t.accent)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(t.accentSoft).cornerRadius(6)
            } else if let score {
                HStack(spacing: 6) {
                    Text("\(score.home):\(score.away)")
                        .font(.system(size: 13, weight: .bold, design: .rounded))
                        .foregroundColor(t.text)
                    FSResultPill(result: score.result, label: score.resultLabel, size: 18)
                }
            } else {
                Image(systemName: "chevron.right")
                    .font(.system(size: 11))
                    .foregroundColor(t.textTer)
            }
        }
        .padding(.horizontal, 12).padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
