import SwiftUI

// MARK: - TeamContextView (팀 내부 탭 뷰)

struct TeamContextView: View {
    let team: Team
    /// 통계·리포트 탭이 공유하는 조회 기간 — 한 탭에서 바꾸면 다른 탭도 따라간다.
    @StateObject private var statsPeriod = StatsPeriod()
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
            Tab("훈련", systemImage: "figure.run") {
                TrainingListView(team: team)
                    .toolbar(.hidden, for: .navigationBar)
            }
            // 리포트는 통계 탭 내부 진입으로 이동 — 탭 6개가 되면 iOS가 '더보기'로 접기 때문
            Tab("통계", systemImage: "chart.bar.fill") {
                TeamStatsContentView(team: team, period: statsPeriod)
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
    @StateObject private var injuryVM: InjuryViewModel
    @StateObject private var trainingVM: TrainingViewModel   // 달력 훈련 마커 + 선택 날짜 훈련 표시용
    @Environment(\.fsTheme) var t
    @State private var selectedDate: Date? = nil
    @State private var checkingTraining: Training? = nil

    init(team: Team) {
        self.team = team
        _matchVM = StateObject(wrappedValue: MatchViewModel(team: team))
        _injuryVM = StateObject(wrappedValue: InjuryViewModel(team: team))
        _trainingVM = StateObject(wrappedValue: TrainingViewModel(team: team))
    }

    private var upcomingMatch: Match? {
        matchVM.matches.upcoming().first
    }

    private var recentFinished: [Match] {
        Array(
            matchVM.matches.past().prefix(5)
        )
    }

    private var selectedDateMatch: Match? {
        guard let date = selectedDate else { return nil }
        return matchVM.matches.first {
            guard let d = $0.parsedDate else { return false }
            return Calendar.current.isDate(d, inSameDayAs: date)
        }
    }

    /// 선택한 날짜의 훈련 세션들 (시간순).
    private var selectedDateTrainings: [Training] {
        guard let date = selectedDate else { return [] }
        return trainingVM.trainings
            .filter {
                guard let d = $0.parsedDate else { return false }
                return Calendar.current.isDate(d, inSameDayAs: date)
            }
            .sorted { $0.trainingdate < $1.trainingdate }
    }

    /// 선택한 날짜가 생일(월·일 일치, 매년 반복)인 선수 목록.
    private var selectedDateBirthdayPlayers: [Player] {
        guard let date = selectedDate else { return [] }
        let cal = Calendar.current
        let month = cal.component(.month, from: date)
        let day = cal.component(.day, from: date)
        return injuryVM.players.filter { player in
            guard let md = player.birthMonthDay else { return false }
            return md.month == month && md.day == day
        }
    }

    /// "🎂 홍길동 생일 (만 N세)" — 출생 연도를 알 수 없으면 나이 생략.
    private func birthdayLabel(for player: Player, on date: Date) -> String {
        var label = "🎂 \(player.name) 생일"
        if let year = player.birthYear {
            let age = Calendar.current.component(.year, from: date) - year
            if age >= 0 { label += " (만 \(age)세)" }
        }
        return label
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 0) {
                FSTeamHeader(team: team, tab: .home)

                TeamSummaryCard(team: team, matches: matchVM.matches, recentMatches: recentFinished, matchScores: matchVM.matchScores)
                
                // 달력 (경기일 + 훈련일 + 선수 생일 마커)
                FSCalendarView(matches: matchVM.matches, trainings: trainingVM.trainings, players: injuryVM.players, selectedDate: $selectedDate)
                    .padding(.top, 8)

                // 경기 · 훈련
                let displayedMatch = selectedDate != nil ? selectedDateMatch : upcomingMatch
                let dayTrainings = selectedDateTrainings
                let sectionTitle: String = {
                    guard let d = selectedDate else { return "다음 경기" }
                    let f = DateFormatter()
                    f.dateFormat = "M월 d일 일정"
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
                    if dayTrainings.isEmpty {
                        Text("해당 날짜에 일정이 없습니다")
                            .font(.system(size: 13))
                            .foregroundColor(t.textSec)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                    }
                } else if matchVM.isLoading {
                    ProgressView().frame(maxWidth: .infinity).padding(.vertical, 20)
                } else {
                    Text("예정된 경기가 없습니다")
                        .font(.system(size: 13))
                        .foregroundColor(t.textSec)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                }

                // 선택한 날짜의 훈련 (경기와 같은 날이면 경기 카드 아래에 함께 표시)
                if !dayTrainings.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(dayTrainings.enumerated()), id: \.element.id) { i, training in
                            Button {
                                checkingTraining = training
                            } label: {
                                HomeTrainingRow(
                                    training: training,
                                    attendedCount: trainingVM.attendances(for: training.id).count,
                                    playerCount: trainingVM.players.count
                                )
                            }
                            .buttonStyle(.plain)
                            if i < dayTrainings.count - 1 {
                                Divider().background(t.line)
                            }
                        }
                    }
                    .fsCard()
                    .padding(.horizontal, 16)
                    .padding(.top, displayedMatch != nil ? 8 : 0)
                }

                // 선택한 날짜의 선수 생일
                let birthdayPlayers = selectedDateBirthdayPlayers
                if let date = selectedDate, !birthdayPlayers.isEmpty {
                    VStack(spacing: 0) {
                        ForEach(Array(birthdayPlayers.enumerated()), id: \.element.id) { i, player in
                            HStack {
                                Text(birthdayLabel(for: player, on: date))
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(t.text)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            if i < birthdayPlayers.count - 1 {
                                Divider().background(t.line)
                            }
                        }
                    }
                    .fsCard()
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }

                // 부상자 명단
                InjurySection(vm: injuryVM, isReadOnly: true)

                // 최근 완료 경기
                if !recentFinished.isEmpty {
                    FSSectionHeader(title: "최근 경기")
                    VStack(spacing: 0) {
                        ForEach(Array(recentFinished.enumerated()), id: \.element.id) { i, match in
                            NavigationLink(value: match) {
                                MatchRow(match: match, score: matchVM.matchScores[match.id])
                            }
                            .buttonStyle(.plain)
                            if i < recentFinished.count - 1 {
                                Divider().background(t.line)
                            }
                        }
                    }
                    .fsCard()
                    .padding(.horizontal, 16)
                }
            }
            .padding(.bottom, 10)
        }
        .background(t.bg.ignoresSafeArea())
        .sheet(item: $checkingTraining) { training in
            // 훈련 탭과 동일한 참석 체크 시트 — 홈에서 해당 훈련으로 바로 진입
            AttendanceFormView(vm: trainingVM, training: training)
                .environment(\.fsTheme, t)
        }
        .task { await matchVM.fetchMatches() }
        .task { await injuryVM.fetch() }
        .task { await trainingVM.fetch() }
        .onReceive(NotificationCenter.default.publisher(for: .matchDeleted)) { note in
            if let id = note.userInfo?["matchId"] as? Int {
                matchVM.removeMatch(id: id)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .playerDeleted)) { _ in
            Task { await injuryVM.fetch() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .injuryChanged)) { _ in
            // 선수단 탭에서 부상을 등록·수정하면 홈 섹션 즉시 갱신
            Task { await injuryVM.fetch() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .trainingChanged)) { _ in
            // 훈련 탭에서 훈련·참석을 바꾸면 홈 달력 마커·훈련 카드 즉시 갱신
            Task { await trainingVM.fetch() }
        }
    }
}

// MARK: - HomeTrainingRow (홈 달력에서 선택한 날짜의 훈련)

private struct HomeTrainingRow: View {
    let training: Training
    let attendedCount: Int
    let playerCount: Int
    @Environment(\.fsTheme) var t

    private var timeString: String {
        guard let d = training.parsedDate else { return "" }
        let f = DateFormatter()
        f.dateFormat = "HH:mm"
        return f.string(from: d)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "figure.run")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(t.pos)
                .frame(width: 32, height: 32)
                .background(t.pos.opacity(0.13))
                .clipShape(Circle())

            HStack(spacing: 6) {
                Text("훈련")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(t.text)
                Text(timeString)
                    .font(.system(size: 12, design: .rounded))
                    .foregroundColor(t.textSec)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("참석 \(attendedCount)/\(playerCount)명")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(t.textSec)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
    }
}

// MARK: - TeamSummaryCard

private struct TeamSummaryCard: View {
    let team: Team
    let matches: [Match]
    let recentMatches: [Match]
    let matchScores: [Int: MatchScore]
    @Environment(\.fsTheme) var t

    private var totalCount: Int { matches.count }
    private var upcomingCount: Int { matches.filter { $0.isUpcoming }.count }
    private var finishedCount: Int { matches.filter { !$0.isUpcoming }.count }

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
                            FSResultPill(result: matchScores[match.id]?.result ?? "?", size: 22)
                                .opacity(matchScores[match.id] == nil ? 0.25 : 1)
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
        match.isUpcoming
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
    var trainings: [Training] = []
    let players: [Player]
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

    private func hasTraining(on date: Date) -> Bool {
        trainings.contains {
            guard let d = $0.parsedDate else { return false }
            return cal.isDate(d, inSameDayAs: date)
        }
    }

    /// 선수 생일(월·일) 집합 — 매년 반복되므로 연도는 무시. 키는 month*100+day.
    private var birthdayKeys: Set<Int> {
        Set(players.compactMap { player in
            player.birthMonthDay.map { $0.month * 100 + $0.day }
        })
    }

    private func hasBirthday(on date: Date, keys: Set<Int>) -> Bool {
        keys.contains(cal.component(.month, from: date) * 100 + cal.component(.day, from: date))
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
            let bdayKeys = birthdayKeys
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 0), count: 7), spacing: 4) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, date in
                    if let date = date {
                        let isSelected = selectedDate.map { cal.isDate($0, inSameDayAs: date) } ?? false
                        let isToday = cal.isDateInToday(date)
                        let hasMatchDay = hasMatch(on: date)
                        let hasTrainingDay = hasTraining(on: date)
                        let hasBirthdayDay = hasBirthday(on: date, keys: bdayKeys)
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

                                // 경기일 점(accent) + 훈련일 점(pos) + 생일 점(yellow) — 없으면 자리만 유지
                                HStack(spacing: 3) {
                                    if hasMatchDay {
                                        Circle().fill(t.accent).frame(width: 4, height: 4)
                                    }
                                    if hasTrainingDay {
                                        Circle().fill(t.pos).frame(width: 4, height: 4)
                                    }
                                    if hasBirthdayDay {
                                        Circle().fill(t.yellow).frame(width: 4, height: 4)
                                    }
                                }
                                .frame(height: 4)
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
