import SwiftUI

struct RecordView: View {
    @StateObject private var vm: RecordViewModel
    @StateObject private var injuryVM: InjuryViewModel   // 부상 등록 시트용 — 네트워크는 시트 오픈 시에만
    let match: Match
    @Environment(\.fsTheme) var t
    @Environment(\.dismiss) var dismiss

    @State private var activePid: Int? = nil
    @State private var injuryDraft: InjuryDraft? = nil

    init(quarter: Quarter, team: Team, match: Match) {
        self.match = match
        _vm = StateObject(wrappedValue: RecordViewModel(quarter: quarter, team: team, match: match))
        _injuryVM = StateObject(wrappedValue: InjuryViewModel(team: team))
    }

    // 부상 발생일 프리필 = 경기일. 폼의 DatePicker 범위(...오늘) 때문에 미래(예정) 경기는 오늘로 clamp
    private var injuryStartdate: String {
        let matchDay = match.matchdate.dayPrefix
        let today = Date.todayYMD
        return matchDay.isEmpty ? today : min(matchDay, today)
    }

    private var quarterLabel: String {
        "Q\(vm.quarter.number)"
    }

    private var totalGoals: Int { vm.totalGoals }
    private var totalAssists: Int { vm.totalAssists }

    var body: some View {
        ZStack {

            ScrollView {
                VStack(spacing: 0) {
                    // 네비
                    HStack {
                        FSGlassButton(action: { dismiss() }) {
                            Image(systemName: "arrow.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(t.text)
                        }
                        Spacer()
                        Text("vs \(match.awayname) · \(quarterLabel)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(t.textSec)
                        Spacer()
                        // 좌측 뒤로가기 버튼과 폭을 맞춰 타이틀 중앙 정렬 유지
                        Color.clear.frame(width: 36, height: 36)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 58)
                    .padding(.bottom, 8)

                    // 합계 카드
                    HStack(spacing: 0) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("이 쿼터 합계")
                                .font(.system(size: 10, weight: .bold)).kerning(0.4).textCase(.uppercase)
                                .foregroundColor(t.textTer)
                            HStack(alignment: .lastTextBaseline, spacing: 8) {
                                HStack(alignment: .lastTextBaseline, spacing: 3) {
                                    Text("\(totalGoals)")
                                        .font(.system(size: 24, weight: .black, design: .rounded))
                                        .foregroundColor(t.accent)
                                    Text("G").font(.system(size: 12, weight: .semibold)).foregroundColor(t.textSec)
                                }
                                HStack(alignment: .lastTextBaseline, spacing: 3) {
                                    Text("\(totalAssists)")
                                        .font(.system(size: 24, weight: .black, design: .rounded))
                                        .foregroundColor(t.text)
                                    Text("A").font(.system(size: 12, weight: .semibold)).foregroundColor(t.textSec)
                                }
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)

                        Rectangle().fill(t.line).frame(width: 0.5, height: 44)

                        VStack(alignment: .leading, spacing: 2) {
                            Text("출전 선수").font(.system(size: 10, weight: .bold)).kerning(0.4).textCase(.uppercase)
                                .foregroundColor(t.textTer)
                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text("\(vm.playedCount)")
                                    .font(.system(size: 24, weight: .black, design: .rounded))
                                    .foregroundColor(t.text)
                                Text("/ \(vm.players.count)명")
                                    .font(.system(size: 12)).foregroundColor(t.textSec)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.leading, 14)
                    }
                    .padding(14)
                    .background(t.bgElev)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.line, lineWidth: 0.5))
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)

                    // 컬럼 헤더 — 폭/간격/인셋을 카드 컨트롤과 동일하게 맞춰 정렬
                    HStack(spacing: 6) {
                        Text("선수").frame(maxWidth: .infinity, alignment: .leading)
                        Text("출전(분)").frame(width: 52, alignment: .center)
                        Text("골").frame(width: 74, alignment: .center)
                        Text("도움").frame(width: 74, alignment: .center)
                    }
                    .font(.system(size: 10, weight: .bold)).kerning(0.4).textCase(.uppercase)
                    .foregroundColor(t.textTer)
                    .padding(.horizontal, 26).padding(.bottom, 8)

                    // 선수 기록 카드
                    if vm.isLoading {
                        ProgressView().padding(.top, 40)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(vm.players) { player in
                                let injured = vm.isInjured(player.id)
                                let isActive = activePid == player.id && !injured

                                RecordPlayerCard(
                                    player: player,
                                    draft: vm.draft(for: player.id),
                                    isActive: isActive,
                                    isInjured: injured,
                                    maxMinutes: vm.quarter.duration,
                                    assistCap: vm.assistCap(for: player.id),
                                    onTap: {
                                        guard !injured else { return }
                                        activePid = isActive ? nil : player.id
                                    },
                                    onUpdate: { min, goal, assist, yellow, red in
                                        vm.updateDraft(playerId: player.id, min: min, goal: goal, assist: assist, yellowcard: yellow, redcard: red)
                                    },
                                    onRegisterInjury: {
                                        injuryDraft = .new(playerId: player.id, startdate: injuryStartdate)
                                    }
                                )
                            }
                        }
                        .padding(.horizontal, 16)
                    }
                }
                .padding(.bottom, 40)
            }
            .ignoresSafeArea(edges: .top)
        }
        .background(t.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task { await vm.fetch() }
        .onDisappear { vm.flushPendingSaves() }
        .sheet(item: $injuryDraft) { draft in
            InjuryFormView(vm: injuryVM, draft: draft)
                .environment(\.fsTheme, t)
                .task { await injuryVM.fetch() }   // 선수 Picker·부상 중 표시용 데이터
        }
        // 시트에서 부상 저장 시 입력 차단 상태 즉시 반영 (drafts는 건드리지 않음)
        .onReceive(NotificationCenter.default.publisher(for: .injuryChanged)) { _ in
            Task { await vm.refreshInjuries() }
        }
        .alert(
            "저장 실패",
            isPresented: Binding(get: { vm.errorMessage != nil }, set: { if !$0 { vm.errorMessage = nil } })
        ) {
            Button("확인", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }
}

// MARK: - RecordPlayerCard

struct RecordPlayerCard: View {
    let player: Player
    let draft: RecordViewModel.Draft
    let isActive: Bool
    let isInjured: Bool
    let maxMinutes: Int
    let assistCap: Int   // 이 선수가 가질 수 있는 최대 어시스트(자기 골 어시 불가 + 팀 골 합 초과 불가)
    let onTap: () -> Void
    let onUpdate: (Int, Int, Int, Int, Int) -> Void
    let onRegisterInjury: () -> Void   // 경기 중 부상 발생 시 이 화면에서 바로 등록

    @State private var mins: Int
    @State private var goals: Int
    @State private var assists: Int
    @State private var yellows: Int
    @State private var reds: Int
    @State private var minsText: String
    @FocusState private var minsFocused: Bool
    @Environment(\.fsTheme) var t

    init(player: Player, draft: RecordViewModel.Draft, isActive: Bool, isInjured: Bool = false, maxMinutes: Int, assistCap: Int, onTap: @escaping () -> Void, onUpdate: @escaping (Int, Int, Int, Int, Int) -> Void, onRegisterInjury: @escaping () -> Void = {}) {
        self.player = player
        self.draft = draft
        self.isActive = isActive
        self.isInjured = isInjured
        self.maxMinutes = maxMinutes
        self.assistCap = assistCap
        self.onTap = onTap
        self.onUpdate = onUpdate
        self.onRegisterInjury = onRegisterInjury
        _mins = State(initialValue: draft.min)
        _minsText = State(initialValue: draft.min == 0 ? "" : "\(draft.min)")
        _goals = State(initialValue: draft.goal)
        _assists = State(initialValue: draft.assist)
        _yellows = State(initialValue: draft.yellowcard)
        _reds = State(initialValue: draft.redcard)
    }

    // 외부(서버 재조회 등)에서 draft가 바뀌면 로컬 입력 상태 동기화.
    // 로컬 편집으로 인한 변경은 값이 같아 no-op이라 사용자 입력과 충돌하지 않음.
    private func syncFromDraft(_ d: RecordViewModel.Draft) {
        if d.min != mins {
            mins = d.min
            minsText = d.min == 0 ? "" : "\(d.min)"
        }
        if d.goal != goals { goals = d.goal }
        if d.assist != assists { assists = d.assist }
        if d.yellowcard != yellows { yellows = d.yellowcard }
        if d.redcard != reds { reds = d.redcard }
    }

    var body: some View {
        VStack(spacing: 0) {
        HStack(spacing: 6) {
            FSPlayerAvatar(number: player.number, size: isActive ? 38 : 34)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(player.name).font(.system(size: 14, weight: .bold)).foregroundColor(t.text)
                    if isInjured {
                        Text("부상")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(t.neg)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(t.neg.opacity(0.13))
                            .cornerRadius(4)
                    }
                }
                if let pos = player.pos {
                    FSPosChip(pos: pos)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            // 출전 시간 직접 입력
            HStack(spacing: 2) {
                TextField("0", text: $minsText)
                    .keyboardType(.numberPad)
                    .focused($minsFocused)
                    .multilineTextAlignment(.center)
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(t.text)
                    .frame(width: 36)
                    .onChange(of: minsText) { _, val in
                        // 숫자만 허용 + 0~상한 보정(상한 = 120 또는 쿼터 시간 중 큰 값). 보정값을 텍스트에 되써 표시/저장 불일치 방지
                        let clamped = min(max(120, maxMinutes), Int(val.filter(\.isNumber)) ?? 0)
                        let normalized = clamped == 0 ? "" : "\(clamped)"
                        if normalized != minsText { minsText = normalized }   // 재귀 방지 위해 비교 후 갱신
                        if clamped != mins { mins = clamped; save() }
                    }
                    .onSubmit { save() }
                Text("'")
                    .font(.system(size: 12))
                    .foregroundColor(t.textSec)
            }
            .frame(width: 52, alignment: .center)
            .padding(.vertical, 6)
            .background(minsFocused ? t.accentSoft : t.bgElev3)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(minsFocused ? t.accent : Color.clear, lineWidth: 1))
            FSStepper(value: goals, accent: true, small: true, onDecrement: { goals = max(0, goals - 1); save() }, onIncrement: { goals = min(9, goals + 1); save() })
            FSStepper(value: assists, accent: true, small: true, canIncrement: assists < min(9, assistCap), onDecrement: { assists = max(0, assists - 1); save() }, onIncrement: { assists = min(9, assistCap, assists + 1); save() })
        }

            // 카드·풀타임 — 활성(탭) 시에만 노출
            if isActive {
                Rectangle().fill(t.line).frame(height: 0.5).padding(.vertical, 8)

                // 옐로/레드 카드
                HStack(spacing: 10) {
                    cardRow(label: "옐로", color: Color(red: 0.96, green: 0.78, blue: 0.10),
                            value: yellows,
                            onDecrement: { yellows = max(0, yellows - 1); save() },
                            onIncrement: { yellows = min(2, yellows + 1); save() })
                    cardRow(label: "레드", color: Color(red: 0.88, green: 0.15, blue: 0.18),
                            value: reds,
                            onDecrement: { reds = max(0, reds - 1); save() },
                            onIncrement: { reds = min(1, reds + 1); save() })
                }
                .padding(.bottom, 8)

                HStack(spacing: 8) {
                    Button {
                        minsText = "\(maxMinutes)"   // onChange가 0~120 클램프·mins 갱신·save 처리
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "arrow.up.to.line")
                                .font(.system(size: 12, weight: .bold))
                            Text("풀타임 \(maxMinutes)' 채우기")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(t.accent)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 9)
                        .background(t.accentSoft)
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)

                    // 경기 중 부상 — 발생일이 경기일로 프리필된 등록 시트를 연다
                    Button {
                        onRegisterInjury()
                    } label: {
                        HStack(spacing: 6) {
                            Image(systemName: "cross.case")
                                .font(.system(size: 12, weight: .bold))
                            Text("부상 등록")
                                .font(.system(size: 13, weight: .bold))
                        }
                        .foregroundColor(t.neg)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 9)
                        .background(t.neg.opacity(0.1))
                        .cornerRadius(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .padding(10)
        .background(t.bgElev)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(isActive ? t.accent : t.line, lineWidth: isActive ? 1 : 0.5)
        )
        .shadow(color: isActive ? t.accent.opacity(0.15) : .clear, radius: 6, x: 0, y: 2)
        .contentShape(Rectangle())
        .onTapGesture { onTap() }
        .disabled(isInjured)   // 부상 선수는 입력(탭/스테퍼/시간) 전부 비활성
        .opacity(isInjured ? 0.5 : (mins == 0 && !isActive ? 0.65 : 1))
        .onChange(of: draft) { _, newDraft in syncFromDraft(newDraft) }
    }

    // 옐로/레드 카드 한 줄: 색 칩 + 라벨 + 스테퍼
    private func cardRow(label: String, color: Color, value: Int,
                         onDecrement: @escaping () -> Void, onIncrement: @escaping () -> Void) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 11, height: 15)
            Text(label)
                .font(.system(size: 12, weight: .bold))
                .foregroundColor(t.textSec)
            Spacer(minLength: 4)
            FSStepper(value: value, accent: false, small: true, onDecrement: onDecrement, onIncrement: onIncrement)
        }
        .frame(maxWidth: .infinity)
    }

    // 값 변경 즉시 ViewModel에 전달 → 합계 즉시 갱신. 서버 저장 디바운스는 ViewModel이 담당
    private func save() {
        onUpdate(mins, goals, assists, yellows, reds)
    }
}
