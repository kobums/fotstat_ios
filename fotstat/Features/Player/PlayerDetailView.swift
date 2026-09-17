import SwiftUI

/// 선수 상세 — fotmob 선수 페이지의 3단 패턴(요약 타일 → 경기별 기록 → 팀 내 위치)에
/// 부상 이력·훈련 참석·인바디를 더한 화면. 선수단 탭 행에서 push 되며 수정·삭제는
/// 상단 툴바에서 한다. 아이패드(regular)는 본문 | 우측 레일 2단, 아이폰은 세로 스택.
/// 웹 features/player/PlayerDetailPage 미러.
struct PlayerDetailView: View {
    let team: Team
    @State private var player: Player
    @StateObject private var vm: PlayerDetailViewModel
    @StateObject private var playerVM: PlayerViewModel
    @StateObject private var trainingVM: TrainingViewModel
    @StateObject private var inbodyVM: InbodyViewModel
    @Environment(\.fsTheme) var t
    @Environment(\.dismiss) private var dismiss
    @Environment(\.horizontalSizeClass) private var hSize
    @State private var showEdit = false
    @State private var playerToDelete: Player? = nil
    @State private var showInbody = false

    init(player: Player, team: Team) {
        self.team = team
        _player = State(initialValue: player)
        _vm = StateObject(wrappedValue: PlayerDetailViewModel(team: team, playerId: player.id))
        _playerVM = StateObject(wrappedValue: PlayerViewModel(team: team))
        _trainingVM = StateObject(wrappedValue: TrainingViewModel(team: team))
        _inbodyVM = StateObject(wrappedValue: InbodyViewModel(team: team))
    }

    // MARK: - 파생값

    private var stat: PlayerStats? { vm.playerStat }
    private var games: Int { stat?.games ?? 0 }

    private func perGame(_ v: Int) -> Double {
        games > 0 ? Double(v) / Double(games) : 0
    }

    /// 기간 내 훈련이 하나라도 있을 때만 참석 통계를 보여준다.
    private var hasTrainingInRange: Bool {
        let today = Date.todayYMD
        return trainingVM.trainings.contains {
            let day = $0.trainingdate.dayPrefix
            return day <= today
                && (vm.startDay.map { day >= $0 } ?? true)
                && (vm.endDay.map { day <= $0 } ?? true)
        }
    }

    private var myTraining: TrainingViewModel.PlayerTrainingStats? {
        guard hasTrainingInRange else { return nil }
        return trainingVM.stats(for: player.id, from: vm.startDay, to: vm.endDay)
    }

    /// 순위 카드의 참석률 행 — 스쿼드 전원의 참석률.
    private var attendanceRates: [Int: Int]? {
        guard hasTrainingInRange else { return nil }
        var map: [Int: Int] = [:]
        for p in vm.squad {
            map[p.id] = trainingVM.stats(for: p.id, from: vm.startDay, to: vm.endDay).rate
        }
        return map
    }

    private var latestInbody: Inbody? { inbodyVM.latest(for: player.id) }

    /// 만 나이 — 생일 "yyyy-MM-dd" 기준. 형식이 어긋나면 nil.
    private var age: Int? {
        guard let b = player.birthdate, let d = DateFormats.day.date(from: b.dayPrefix) else { return nil }
        let years = Calendar.current.dateComponents([.year], from: d, to: Date()).year ?? -1
        return (0..<150).contains(years) ? years : nil
    }

    private var twoCol: Bool { hSize == .regular }

    // MARK: - Body

    var body: some View {
        ZStack {
            t.bg.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 16) {
                    header
                    profileCard
                    periodFilter

                    if twoCol {
                        HStack(alignment: .top, spacing: 16) {
                            mainColumn.frame(maxWidth: .infinity)
                            asideColumn.frame(width: 320)
                        }
                    } else {
                        mainColumn
                        asideColumn
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 40)
            }
        }
        .task { await vm.fetch() }
        .task { await trainingVM.fetch() }
        .task { await inbodyVM.fetch() }
        .onChange(of: vm.periodKey) { _, _ in Task { await vm.fetch() } }
        .onReceive(NotificationCenter.default.publisher(for: .injuryChanged)) { _ in
            Task { await vm.fetch() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .trainingChanged)) { _ in
            Task { await trainingVM.fetch() }
        }
        .sheet(isPresented: $showEdit) {
            PlayerFormView(title: "선수 수정", initialName: player.name, initialNumber: player.number,
                           initialPos: player.pos, initialBirthdate: player.birthdate) { name, number, pos, birthdate in
                Task {
                    await playerVM.updatePlayer(id: player.id, name: name, number: number, pos: pos, birthdate: birthdate)
                    if let updated = playerVM.players.first(where: { $0.id == player.id }) { player = updated }
                }
            }
            .environment(\.fsTheme, t)
        }
        .sheet(isPresented: $showInbody) {
            PlayerInbodyView(vm: inbodyVM, playerId: player.id)
                .environment(\.fsTheme, t)
        }
        .deleteConfirmation(
            "선수 삭제",
            item: $playerToDelete,
            message: { "'\($0.name)' 선수와 해당 선수의 경기 기록·부상 내역이 모두 삭제됩니다. 이 작업은 되돌릴 수 없습니다." },
            onDelete: { p in
                Task {
                    // 성공 시 목록으로 복귀 (PlayerListView는 .playerDeleted 알림으로 재조회)
                    if await playerVM.deletePlayer(id: p.id) { dismiss() }
                }
            }
        )
        .errorAlert($playerVM.errorMessage)
        .toolbar(.hidden, for: .navigationBar)
    }

    // MARK: - 헤더 (뒤로 · 팀 이름 · 수정 · 삭제)

    private var header: some View {
        HStack {
            FSGlassButton(action: { dismiss() }) {
                Image(systemName: "chevron.left")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundColor(t.text)
            }
            Spacer()
            Text(team.name)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(t.textSec)
            Spacer()
            HStack(spacing: 8) {
                FSGlassButton(action: { showEdit = true }) {
                    Image(systemName: "pencil")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(t.text)
                }
                FSGlassButton(action: { playerToDelete = player }) {
                    Image(systemName: "trash")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(t.neg)
                }
                .disabled(playerVM.deletingIds.contains(player.id))
            }
        }
        .padding(.top, 8)
    }

    // MARK: - 프로필 (fotmob 히어로 + 팩트 그리드를 한 줄로)

    private var profileCard: some View {
        HStack(spacing: 16) {
            FSPlayerAvatar(number: player.number, size: 72)
            VStack(alignment: .leading, spacing: 6) {
                Text(player.name)
                    .font(.system(size: 24, weight: .black))
                    .foregroundColor(t.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                HStack(spacing: 8) {
                    Text("#\(player.number ?? 0)")
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(t.textSec)
                    if let pos = player.pos { FSPosChip(pos: pos) }
                }
                HStack(spacing: 12) {
                    if let b = player.birthdate, !b.isEmpty {
                        Text(b.dayPrefix.replacingOccurrences(of: "-", with: ".")
                             + (age.map { " (만 \($0)세)" } ?? ""))
                    }
                    if let ib = latestInbody, ib.height > 0 || ib.weight > 0 {
                        Text([ib.height > 0 ? "\(inbodyValue(ib.height))cm" : nil,
                              ib.weight > 0 ? "\(inbodyValue(ib.weight))kg" : nil]
                            .compactMap { $0 }.joined(separator: " · "))
                    }
                }
                .font(.system(size: 13, design: .rounded))
                .foregroundColor(t.textTer)
            }
            Spacer(minLength: 0)
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .fsCard()
    }

    // MARK: - 기간

    /// "전체 기간 보기"로 둘 다 nil 이 되면 필터의 X 버튼이 남는데, 이는 의도된 동작 —
    /// 기본 기간(올해)으로 되돌아가는 유일한 경로다.
    private var periodFilter: some View {
        HStack(spacing: 10) {
            DateRangeFilter(startDate: $vm.startDate, endDate: $vm.endDate,
                            onApply: {}, defaultStart: DateRangeFilter.yearStart)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text(vm.isRanged ? "선택 기간" : "전체 기간")
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(t.textTer)
        }
    }

    // MARK: - 본문 컬럼 (요약 · 경기별 기록 · 인바디)

    @ViewBuilder
    private var mainColumn: some View {
        VStack(spacing: 16) {
            if vm.isLoading && vm.stats == nil {
                ProgressView().frame(maxWidth: .infinity).padding(.vertical, 40)
            } else {
                summarySection
                section("경기별 기록") {
                    PlayerMatchLogList(logs: vm.matchLogs, matches: vm.raw?.finished)
                }
            }
            inbodySection
        }
    }

    /// 요약 타일 8개 — fotmob 시즌 요약 카드 미러. 2줄 × 4.
    @ViewBuilder
    private var summarySection: some View {
        VStack(spacing: 8) {
            if vm.isRanged, let s = vm.stats, s.matchCount == 0 {
                HStack {
                    Text("이 기간에 경기가 없습니다.")
                        .font(.system(size: 13))
                        .foregroundColor(t.textSec)
                    Spacer()
                    Button("전체 기간 보기") { vm.clearPeriod() }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(t.accent)
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .fsCard()
            }
            HStack(spacing: 8) {
                FSMiniStatTile("경기", value: games)
                FSMiniStatTile("골", value: stat?.goal ?? 0,
                               sub: String(format: "경기당 %.2f", perGame(stat?.goal ?? 0)), accent: true)
                FSMiniStatTile("도움", value: stat?.assist ?? 0,
                               sub: String(format: "경기당 %.2f", perGame(stat?.assist ?? 0)))
                FSMiniStatTile("출전 분", value: stat?.min ?? 0, suffix: "'",
                               sub: "경기당 \(Int(perGame(stat?.min ?? 0).rounded()))'")
            }
            HStack(spacing: 8) {
                FSMiniStatTile("경고", value: stat?.yellow ?? 0, sub: "🟨")
                FSMiniStatTile("퇴장", value: stat?.red ?? 0, sub: "🟥")
                FSMiniStatTile("공격P", value: (stat?.goal ?? 0) + (stat?.assist ?? 0), sub: "골+도움")
                FSMiniStatTile("결장", value: stat?.absentGames ?? 0, sub: "부상")
            }
        }
    }

    /// 인바디 — 최신 요약 + 이력·추이 시트 진입.
    @ViewBuilder
    private var inbodySection: some View {
        let action: (String, () -> Void)? = latestInbody == nil ? nil : ("이력·추이", { showInbody = true })
        section("인바디", action: action) {
            if let latest = latestInbody {
                InbodyLatestSummary(latest: latest)
            } else {
                HStack {
                    Text("측정 기록이 없습니다")
                        .font(.system(size: 13))
                        .foregroundColor(t.textTer)
                    Spacer()
                    Button("측정 추가") { showInbody = true }
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(t.accent)
                }
                .padding(.horizontal, 12).padding(.vertical, 14)
                .fsCard()
            }
        }
    }

    // MARK: - 우측 레일 (팀 내 위치 · 부상 이력 · 훈련 참석)

    @ViewBuilder
    private var asideColumn: some View {
        if !(vm.isLoading && vm.stats == nil) {
            VStack(spacing: 16) {
                TeamRankCard(playerId: player.id, squad: vm.squad, attendance: attendanceRates)
                section("부상 이력") {
                    PlayerInjuryList(injuries: vm.injuries)
                }
                section("훈련 참석") {
                    if let s = myTraining {
                        HStack(spacing: 8) {
                            FSMiniStatTile("참석", value: "\(s.attended)/\(s.held)", sub: "회")
                            FSMiniStatTile("참석률", value: "\(s.rate)%")
                            FSMiniStatTile("훈련 시간", value: s.totalMin, sub: "분")
                        }
                    } else {
                        Text(vm.isRanged ? "이 기간에 훈련이 없습니다" : "훈련 기록이 없습니다")
                            .font(.system(size: 13))
                            .foregroundColor(t.textTer)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(.horizontal, 12).padding(.vertical, 14)
                            .fsCard()
                    }
                }
            }
        }
    }

    // MARK: - 섹션 래퍼

    private func section<Content: View>(
        _ title: String,
        action: (String, () -> Void)? = nil,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(title)
                    .font(.system(size: 11, weight: .bold))
                    .kerning(0.5)
                    .foregroundColor(t.textTer)
                Spacer()
                if let action {
                    Button(action.0, action: action.1)
                        .font(.system(size: 12, weight: .bold))
                        .foregroundColor(t.accent)
                }
            }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
