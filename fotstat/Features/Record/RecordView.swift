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
        switch vm.quarter.number {
        case 1: return "전반"
        case 2: return "후반"
        case 3: return "연장 전반"
        case 4: return "연장 후반"
        default: return "\(vm.quarter.number)쿼터"
        }
    }

    private var totalGoals: Int { vm.records.reduce(0) { $0 + $1.goal } }
    private var totalAssists: Int { vm.records.reduce(0) { $0 + $1.assist } }

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
                            Text("입력 진행").font(.system(size: 10, weight: .bold)).kerning(0.4).textCase(.uppercase)
                                .foregroundColor(t.textTer)
                            HStack(alignment: .lastTextBaseline, spacing: 4) {
                                Text("\(vm.records.count)")
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

                    // 컬럼 헤더
                    HStack {
                        Text("선수").frame(maxWidth: .infinity, alignment: .leading)
                        Text("출전(분)").frame(width: 80, alignment: .center)
                        Text("골").frame(width: 70, alignment: .center)
                        Text("도움").frame(width: 70, alignment: .center)
                    }
                    .font(.system(size: 10, weight: .bold)).kerning(0.4).textCase(.uppercase)
                    .foregroundColor(t.textTer)
                    .padding(.horizontal, 22).padding(.bottom, 8)

                    // 선수 기록 카드
                    if vm.isLoading {
                        ProgressView().padding(.top, 40)
                    } else {
                        VStack(spacing: 6) {
                            ForEach(vm.players) { player in
                                let record = vm.records.first(where: { $0.player == player.id })
                                let isActive = activePid == player.id

                                RecordPlayerCard(
                                    player: player,
                                    record: record,
                                    isActive: isActive,
                                    onTap: { activePid = isActive ? nil : player.id },
                                    onUpdate: { min, goal, assist in
                                        if let r = record {
                                            Task { await vm.updateRecord(id: r.id, min: min, goal: goal, assist: assist) }
                                        } else {
                                            Task { await vm.createRecord(playerId: player.id, min: min, goal: goal, assist: assist) }
                                        }
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
    let record: Record?
    let isActive: Bool
    let onTap: () -> Void
    let onUpdate: (Int, Int, Int) -> Void

    @State private var mins: Int
    @State private var goals: Int
    @State private var assists: Int
    @State private var minsText: String
    @State private var saveTask: Task<Void, Never>? = nil
    @FocusState private var minsFocused: Bool
    @Environment(\.fsTheme) var t

    init(player: Player, record: Record?, isActive: Bool, onTap: @escaping () -> Void, onUpdate: @escaping (Int, Int, Int) -> Void) {
        self.player = player
        self.record = record
        self.isActive = isActive
        self.onTap = onTap
        self.onUpdate = onUpdate
        let initialMins = record?.min ?? 0
        _mins = State(initialValue: initialMins)
        _minsText = State(initialValue: initialMins == 0 ? "" : "\(initialMins)")
        _goals = State(initialValue: record?.goal ?? 0)
        _assists = State(initialValue: record?.assist ?? 0)
    }

    var body: some View {
        HStack(spacing: 8) {
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
                        let clamped = min(120, max(0, Int(val) ?? 0))
                        mins = clamped
                        save()
                    }
                    .onSubmit { save() }
                Text("'")
                    .font(.system(size: 12))
                    .foregroundColor(t.textSec)
            }
            .frame(width: 80, alignment: .center)
            .padding(.vertical, 6)
            .background(minsFocused ? t.accentSoft : t.bgElev3)
            .cornerRadius(8)
            .overlay(RoundedRectangle(cornerRadius: 8).stroke(minsFocused ? t.accent : Color.clear, lineWidth: 1))
            FSStepper(value: goals, accent: true, onDecrement: { goals = max(0, goals - 1); save() }, onIncrement: { goals = min(9, goals + 1); save() })
            FSStepper(value: assists, onDecrement: { assists = max(0, assists - 1); save() }, onIncrement: { assists = min(9, assists + 1); save() })
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

    private func save() {
        saveTask?.cancel()
        saveTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000) // 0.6초 대기
            guard !Task.isCancelled else { return }
            onUpdate(mins, goals, assists)
        }
    }
}
