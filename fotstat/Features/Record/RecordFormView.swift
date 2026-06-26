import SwiftUI

struct RecordFormView: View {
    let players: [Player]
    var initialPlayerId: Int? = nil
    var initialMin: Int = 0
    var initialGoal: Int = 0
    var initialAssist: Int = 0
    var initialYellowcard: Int = 0
    var initialRedcard: Int = 0
    let onSave: (Int, Int, Int, Int, Int, Int) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.fsTheme) var t
    @State private var selectedPlayerId: Int?
    @State private var min: Int
    @State private var goal: Int
    @State private var assist: Int
    @State private var yellowcard: Int
    @State private var redcard: Int

    init(players: [Player], initialPlayerId: Int? = nil, initialMin: Int = 0,
         initialGoal: Int = 0, initialAssist: Int = 0, initialYellowcard: Int = 0,
         initialRedcard: Int = 0, onSave: @escaping (Int, Int, Int, Int, Int, Int) -> Void) {
        self.players = players
        self.initialPlayerId = initialPlayerId
        self.initialMin = initialMin
        self.initialGoal = initialGoal
        self.initialAssist = initialAssist
        self.initialYellowcard = initialYellowcard
        self.initialRedcard = initialRedcard
        self.onSave = onSave
        _selectedPlayerId = State(initialValue: initialPlayerId ?? players.first?.id)
        _min = State(initialValue: initialMin)
        _goal = State(initialValue: initialGoal)
        _assist = State(initialValue: initialAssist)
        _yellowcard = State(initialValue: initialYellowcard)
        _redcard = State(initialValue: initialRedcard)
    }

    var body: some View {
        ZStack {
            t.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Text("취소").foregroundColor(t.textSec)
                    }
                    Spacer()
                    Text(initialPlayerId == nil ? "기록 추가" : "기록 수정")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(t.text)
                    Spacer()
                    Button {
                        if let pid = selectedPlayerId {
                            onSave(pid, min, goal, assist, yellowcard, redcard)
                            dismiss()
                        }
                    } label: {
                        Text("저장")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(selectedPlayerId == nil ? t.textSec : t.accent)
                    }
                    .disabled(selectedPlayerId == nil)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 24)

                List {
                    if initialPlayerId == nil {
                        Section("선수") {
                            ForEach(players) { player in
                                Button {
                                    selectedPlayerId = player.id
                                } label: {
                                    HStack {
                                        if let n = player.number {
                                            Text("\(n)")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(t.textSec)
                                                .frame(width: 24)
                                        }
                                        Text(player.name).foregroundColor(t.text)
                                        Spacer()
                                        if selectedPlayerId == player.id {
                                            Image(systemName: "checkmark").foregroundColor(t.accent)
                                        }
                                    }
                                }
                                .listRowBackground(t.bgElev)
                            }
                        }
                    }

                    Section("기록") {
                        Stepper("출전 시간: \(min)분", value: $min, in: 0...120)
                            .foregroundColor(t.text)
                            .listRowBackground(t.bgElev)
                        Stepper("골: \(goal)", value: $goal, in: 0...20)
                            .foregroundColor(t.text)
                            .listRowBackground(t.bgElev)
                        Stepper("어시스트: \(assist)", value: $assist, in: 0...20)
                            .foregroundColor(t.text)
                            .listRowBackground(t.bgElev)
                        Stepper("옐로카드: \(yellowcard)", value: $yellowcard, in: 0...2)
                            .foregroundColor(t.text)
                            .listRowBackground(t.bgElev)
                        Stepper("레드카드: \(redcard)", value: $redcard, in: 0...1)
                            .foregroundColor(t.text)
                            .listRowBackground(t.bgElev)
                    }
                }
                .listStyle(.insetGrouped)
                .scrollContentBackground(.hidden)
            }
        }
    }
}
