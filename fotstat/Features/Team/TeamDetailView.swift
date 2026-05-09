import SwiftUI

// MARK: - TeamContextView (팀 내부 탭 뷰)

struct TeamContextView: View {
    let team: Team
    @Environment(\.fsTheme) var t
    @Environment(\.dismiss) var dismiss

    var body: some View {
        TabView {
            Tab("홈", systemImage: "house.fill") {
                TeamHomeView(team: team)
                    .toolbar(.hidden, for: .navigationBar)
            }
            Tab("선수단", systemImage: "person.3.fill") {
                PlayerListView(team: team)
                    .toolbar(.hidden, for: .navigationBar)
            }
            Tab("경기", systemImage: "soccerball") {
                MatchListView(team: team)
                    .toolbar(.hidden, for: .navigationBar)
            }
            Tab("통계", systemImage: "chart.bar.fill") {
                TeamStatsContentView(team: team)
                    .toolbar(.hidden, for: .navigationBar)
            }
        }
        .environment(\.fsSelectTeam, { dismiss() })
        .navigationDestination(for: Match.self) { match in
            MatchDetailView(match: match, team: team)
                .environment(\.fsTheme, t)
        }
        .toolbar(.hidden, for: .navigationBar)
        .ignoresSafeArea(.keyboard)
    }
}

// MARK: - TeamHomeView (Home 탭)

struct TeamHomeView: View {
    let team: Team
    @StateObject private var matchVM: MatchViewModel
    @Environment(\.fsTheme) var t
    @State private var selectedDate: Date? = nil

    init(team: Team) {
        self.team = team
        _matchVM = StateObject(wrappedValue: MatchViewModel(team: team))
    }

    private var upcomingMatch: Match? {
        matchVM.matches
            .filter { ($0.parsedDate ?? .distantPast) > Date() }
            .sorted { ($0.parsedDate ?? .distantPast) < ($1.parsedDate ?? .distantPast) }
            .first
    }

    private var recentFinished: [Match] {
        Array(
            matchVM.matches
                .filter { ($0.parsedDate ?? .distantPast) <= Date() }
                .sorted { ($0.parsedDate ?? .distantPast) > ($1.parsedDate ?? .distantPast) }
                .prefix(5)
        )
    }

    private var selectedDateMatch: Match? {
        guard let date = selectedDate else { return nil }
        return matchVM.matches.first {
            guard let d = $0.parsedDate else { return false }
            return Calendar.current.isDate(d, inSameDayAs: date)
        }
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                FSTeamHeader(team: team, tab: .home)

                TeamSummaryCard(team: team, matches: matchVM.matches, recentMatches: recentFinished, matchResults: matchVM.matchResults)
                
                // 달력
                FSCalendarView(matches: matchVM.matches, selectedDate: $selectedDate)
                    .padding(.top, 8)

                // 경기
                let displayedMatch = selectedDate != nil ? selectedDateMatch : upcomingMatch
                let sectionTitle: String = {
                    guard let d = selectedDate else { return "다음 경기" }
                    let f = DateFormatter()
                    f.dateFormat = "M월 d일 경기"
                    f.locale = Locale(identifier: "ko_KR")
                    return f.string(from: d)
                }()
                FSSectionHeader(title: sectionTitle)
                if let match = displayedMatch {
                    NavigationLink(value: match) {
                        UpcomingMatchCard(match: match, team: team)
                    }
                    .buttonStyle(.plain)
                    .padding(.horizontal, 16)
                } else if selectedDate != nil {
                    Text("해당 날짜에 경기가 없습니다")
                        .font(.system(size: 13))
                        .foregroundColor(t.textSec)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                } else if matchVM.isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
                } else {
                    Text("예정된 경기가 없습니다")
                        .font(.system(size: 13))
                        .foregroundColor(t.textSec)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }

                // 최근 완료 경기
                if !recentFinished.isEmpty {
                    FSSectionHeader(title: "최근 경기")
                    VStack(spacing: 0) {
                        ForEach(Array(recentFinished.enumerated()), id: \.element.id) { i, match in
                            NavigationLink(value: match) {
                                MatchRow(match: match, teamName: team.name)
                            }
                            .buttonStyle(.plain)
                            if i < recentFinished.count - 1 {
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
            .padding(.bottom, 10)
        }
        .background(t.bg.ignoresSafeArea())
        .task { await matchVM.fetchMatches() }
    }
}

// MARK: - TeamSummaryCard

private struct TeamSummaryCard: View {
    let team: Team
    let matches: [Match]
    let recentMatches: [Match]
    let matchResults: [Int: String]
    @Environment(\.fsTheme) var t

    private var totalCount: Int { matches.count }
    private var upcomingCount: Int { matches.filter { ($0.parsedDate ?? .distantPast) > Date() }.count }
    private var finishedCount: Int { matches.filter { ($0.parsedDate ?? .distantPast) <= Date() }.count }

    var body: some View {
        VStack(spacing: 0) {
            // 팀 크레스트 + 이름
            HStack(spacing: 14) {
                FSCrest(name: team.name, size: 52, radius: 12)
                Text(team.name)
                    .font(.system(size: 22, weight: .black))
                    .foregroundColor(t.text)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)

            Rectangle().fill(t.line).frame(height: 0.5)

            // 경기 수 통계
            HStack(spacing: 0) {
                StatCell(label: "총 경기", value: "\(totalCount)")
                Rectangle().fill(t.line).frame(width: 0.5, height: 28)
                StatCell(label: "예정", value: "\(upcomingCount)")
                Rectangle().fill(t.line).frame(width: 0.5, height: 28)
                StatCell(label: "완료", value: "\(finishedCount)")
            }

            if !recentMatches.isEmpty {
                Rectangle().fill(t.line).frame(height: 0.5)

                HStack(spacing: 6) {
                    Text("최근 5경기")
                        .font(.system(size: 11, weight: .bold))
                        .kerning(0.4)
                        .foregroundColor(t.textSec)
                    Spacer()
                    HStack(spacing: 4) {
                        ForEach(Array(recentMatches.prefix(5).reversed()), id: \.id) { match in
                            FSResultPill(result: matchResults[match.id] ?? "?", size: 22)
                                .opacity(matchResults[match.id] == nil ? 0.25 : 1)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 12)
            }
        }
        .background(t.bgElev)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(t.line, lineWidth: 0.5))
        .padding(.horizontal, 16)
        .padding(.top, 12)
    }
}


// MARK: - StatCell

private struct StatCell: View {
    let label: String
    let value: String
    @Environment(\.fsTheme) var t

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.system(size: 24, weight: .bold, design: .rounded))
                .foregroundColor(t.text)
            Text(label)
                .font(.system(size: 10, weight: .semibold))
                .kerning(0.4)
                .textCase(.uppercase)
                .foregroundColor(t.textSec)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 14)
    }
}

// MARK: - UpcomingMatchCard

struct UpcomingMatchCard: View {
    let match: Match
    let team: Team
    @Environment(\.fsTheme) var t

    private var dateString: String {
        guard let d = match.parsedDate else { return match.matchdate }
        let f = DateFormatter()
        f.dateFormat = "M월 d일 (E) · HH:mm"
        f.locale = Locale(identifier: "ko_KR")
        return f.string(from: d)
    }

    private var daysUntil: String {
        guard let d = match.parsedDate else { return "" }
        let days = Calendar.current.dateComponents([.day], from: Date(), to: d).day ?? 0
        if days == 0 { return "오늘" }
        if days == 1 { return "내일" }
        if days < 0 { return "\(-days)일 전" }
        return "\(days)일 후"
    }

    private var isFuture: Bool {
        (match.parsedDate ?? .distantPast) > Date()
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text((isFuture ? "예정" : "완료") + " · \(daysUntil)")
                    .font(.system(size: 11, weight: .bold))
                    .foregroundColor(t.accent)
                Spacer()
            }
            .padding(.bottom, 10)

            HStack(spacing: 10) {
                FSCrest(name: team.name, size: 32, radius: 7)
                Text(team.name)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(t.text)
                Spacer()
                Text("VS")
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(t.textSec)
                Spacer()
                Text(match.awayname)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(t.text)
                FSCrest(name: match.awayname, size: 32, radius: 7)
            }

            Text(dateString)
                .font(.system(size: 11))
                .foregroundColor(t.textSec)
                .padding(.top, 10)
        }
        .padding(14)
        .background(t.bgElev)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.line, lineWidth: 0.5))
    }
}

// MARK: - FSTeamHeader (탭 헤더)

struct FSTeamHeader: View {
    let team: Team
    var tab: FSTab = .home
    var onBack: (() -> Void)? = nil
    @Environment(\.fsTheme) var t
    @Environment(\.fsSelectTeam) var selectTeam
    @State private var showSettings = false

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                if let onBack {
                    FSGlassButton(action: onBack) {
                        Image(systemName: "chevron.left")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(t.text)
                    }
                } else {
                    Color.clear.frame(width: 36, height: 36)
                }
                Spacer()
                Button(action: { selectTeam?() }) {
                    HStack(spacing: 4) {
                        Text(team.name)
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(t.text)
                        Image(systemName: "chevron.up.chevron.down")
                            .font(.system(size: 9, weight: .semibold))
                            .foregroundColor(t.textSec)
                    }
                }
                Spacer()
                if tab == .home {
                    Button(action: { showSettings = true }) {
                        Image(systemName: "ellipsis")
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundStyle(t.text)
                            .frame(width: 36, height: 36)
                    }
                    .glassEffect(.regular.interactive(), in: Circle())
                } else {
                    Color.clear.frame(width: 36, height: 36)
                }
            }
            .padding(.horizontal, 12)
            .padding(.top, 12)
            .padding(.bottom, 6)
        }
        .background(t.bg)
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environment(\.fsTheme, t)
        }
    }
}

// MARK: - FSCalendarView

private struct FSCalendarView: View {
    let matches: [Match]
    @Binding var selectedDate: Date?
    @Environment(\.fsTheme) var t

    @State private var displayMonth: Date = Date()

    private let cal = Calendar.current
    private let weekdays = ["일", "월", "화", "수", "목", "금", "토"]

    private func hasMatch(on date: Date) -> Bool {
        matches.contains {
            guard let d = $0.parsedDate else { return false }
            return cal.isDate(d, inSameDayAs: date)
        }
    }

    private var days: [Date?] {
        guard let monthStart = cal.date(from: cal.dateComponents([.year, .month], from: displayMonth)),
              let range = cal.range(of: .day, in: .month, for: monthStart) else { return [] }
        let offset = cal.component(.weekday, from: monthStart) - 1
        var result: [Date?] = Array(repeating: nil, count: offset)
        for i in range {
            result.append(cal.date(byAdding: .day, value: i - 1, to: monthStart))
        }
        return result
    }

    private var monthTitle: String {
        let f = DateFormatter()
        f.dateFormat = "yyyy년 M월"
        f.locale = Locale(identifier: "ko_KR")
        return f.string(from: displayMonth)
    }

    var body: some View {
        VStack(spacing: 10) {
            // 월 네비게이션
            HStack {
                Button {
                    displayMonth = cal.date(byAdding: .month, value: -1, to: displayMonth) ?? displayMonth
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(t.textSec)
                        .frame(width: 32, height: 32)
                }
                Spacer()
                Text(monthTitle)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(t.text)
                Spacer()
                Button {
                    displayMonth = cal.date(byAdding: .month, value: 1, to: displayMonth) ?? displayMonth
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundColor(t.textSec)
                        .frame(width: 32, height: 32)
                }
            }
            .padding(.horizontal, 4)

            // 요일 헤더
            HStack(spacing: 0) {
                ForEach(weekdays, id: \.self) { day in
                    Text(day)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(day == "일" ? t.accent.opacity(0.8) : t.textTer)
                        .frame(maxWidth: .infinity)
                }
            }

            // 날짜 그리드
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        let isSelected = selectedDate.map { cal.isDate($0, inSameDayAs: date) } ?? false
                        let isToday = cal.isDateInToday(date)
                        let hasMatchDay = hasMatch(on: date)
                        let day = cal.component(.day, from: date)

                        Button {
                            selectedDate = isSelected ? nil : date
                        } label: {
                            VStack(spacing: 3) {
                                Text("\(day)")
                                    .font(.system(size: 13, weight: isSelected || isToday ? .bold : .regular))
                                    .foregroundColor(
                                        isSelected ? .white :
                                        isToday ? t.accent :
                                        t.text
                                    )
                                    .frame(width: 30, height: 30)
                                    .background(
                                        isSelected ? t.accent :
                                        isToday ? t.accentSoft :
                                        Color.clear
                                    )
                                    .clipShape(Circle())

                                Circle()
                                    .fill(hasMatchDay ? t.accent : Color.clear)
                                    .frame(width: 4, height: 4)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.plain)
                    } else {
                        Color.clear.frame(height: 44)
                    }
                }
            }
        }
        .padding(14)
        .background(t.bgElev)
        .cornerRadius(16)
        .overlay(RoundedRectangle(cornerRadius: 16).stroke(t.line, lineWidth: 0.5))
        .padding(.horizontal, 16)
    }
}
