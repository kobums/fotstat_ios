import SwiftUI

struct RecordView: View {
    @StateObject private var vm: RecordViewModel
    let match: Match
    @Environment(\.fsTheme) var t
    @Environment(\.dismiss) var dismiss

    @State private var activePid: Int? = nil

    init(quarter: Quarter, team: Team, match: Match) {
        self.match = match
        _vm = StateObject(wrappedValue: RecordViewModel(quarter: quarter, team: team))
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
                        Button { dismiss() } label: {
                            Text("완료")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(.white)
                                .frame(width: 60, height: 32)
                                .background(t.accent)
                                .cornerRadius(16)
                        }
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
                                let isActive = activePid == player.id

                                RecordPlayerCard(
                                    player: player,
                                    draft: vm.draft(for: player.id),
                                    isActive: isActive,
                                    maxMinutes: vm.quarter.duration,
                                    onTap: { activePid = isActive ? nil : player.id },
                                    onUpdate: { min, goal, assist in
                                        vm.updateDraft(playerId: player.id, min: min, goal: goal, assist: assist)
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
    }
}

// MARK: - RecordPlayerCard

struct RecordPlayerCard: View {
    let player: Player
    let isActive: Bool
    let maxMinutes: Int
    let onTap: () -> Void
    let onUpdate: (Int, Int, Int) -> Void

    @State private var mins: Int
    @State private var goals: Int
    @State private var assists: Int
    @State private var minsText: String
    @FocusState private var minsFocused: Bool
    @Environment(\.fsTheme) var t

    init(player: Player, draft: RecordViewModel.Draft, isActive: Bool, maxMinutes: Int, onTap: @escaping () -> Void, onUpdate: @escaping (Int, Int, Int) -> Void) {
        self.player = player
        self.isActive = isActive
        self.maxMinutes = maxMinutes
        self.onTap = onTap
        self.onUpdate = onUpdate
        _mins = State(initialValue: draft.min)
        _minsText = State(initialValue: draft.min == 0 ? "" : "\(draft.min)")
        _goals = State(initialValue: draft.goal)
        _assists = State(initialValue: draft.assist)
    }

    var body: some View {
        VStack(spacing: 0) {
        HStack(spacing: 6) {
            FSPlayerAvatar(number: player.number, size: isActive ? 38 : 34)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(player.name).font(.system(size: 14, weight: .bold)).foregroundColor(t.text)
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
            FSStepper(value: assists, accent: true, small: true, onDecrement: { assists = max(0, assists - 1); save() }, onIncrement: { assists = min(9, assists + 1); save() })
        }

            // 풀타임 빠른 채우기 — 활성(탭) 시에만 노출
            if isActive {
                Rectangle().fill(t.line).frame(height: 0.5).padding(.vertical, 8)
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
        .opacity(mins == 0 && !isActive ? 0.65 : 1)
    }

    // 값 변경 즉시 ViewModel에 전달 → 합계 즉시 갱신. 서버 저장 디바운스는 ViewModel이 담당
    private func save() {
        onUpdate(mins, goals, assists)
    }
}
