import SwiftUI

/// 부상 등록/수정 시트. draft.id 가 있으면 수정(삭제 버튼 노출), 없으면 신규 등록.
struct InjuryFormView: View {
    @ObservedObject var vm: InjuryViewModel
    @Environment(\.fsTheme) var t
    @Environment(\.dismiss) var dismiss

    @State private var playerId: Int
    @State private var type: String
    @State private var startDate: Date
    @State private var hasReturned: Bool
    @State private var returnDate: Date
    @State private var memo: String
    @State private var isSaving = false

    private let editingId: Int?

    init(vm: InjuryViewModel, draft: InjuryDraft) {
        self.vm = vm
        self.editingId = draft.id
        _playerId = State(initialValue: draft.playerId)
        _type = State(initialValue: draft.type)
        _startDate = State(initialValue: DateFormats.day.date(from: draft.startdate) ?? Date())
        _hasReturned = State(initialValue: !draft.returndate.isEmpty)
        _returnDate = State(initialValue: DateFormats.day.date(from: draft.returndate) ?? Date())
        _memo = State(initialValue: draft.memo)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("선수") {
                    if editingId == nil {
                        // 이미 부상 중인 선수는 표시해 실수 중복 등록을 방지 (의도적 복수 부상 등록은 허용)
                        let injured = vm.activeInjuredPlayerIds
                        Picker("선수", selection: $playerId) {
                            ForEach(vm.players) { player in
                                Text(playerLabel(player) + (injured.contains(player.id) ? " · 부상 중" : ""))
                                    .tag(player.id)
                            }
                        }
                    } else {
                        // 수정 시 선수는 변경 대상이 아니므로 표시만 한다
                        LabeledContent("선수") {
                            Text(vm.players.first { $0.id == playerId }.map(playerLabel) ?? vm.playerName(for: playerId))
                        }
                    }
                }

                Section("부상 정보") {
                    TextField("부상 부위/종류 (예: 발목 염좌)", text: $type)
                    DatePicker("발생일", selection: $startDate, in: ...Date(), displayedComponents: .date)
                    Toggle("복귀 완료", isOn: $hasReturned)
                    if hasReturned {
                        DatePicker("복귀일", selection: $returnDate, in: startDate...Date(), displayedComponents: .date)
                    }
                }

                Section("메모") {
                    TextField("메모 (선택)", text: $memo, axis: .vertical)
                        .lineLimit(2...5)
                }

                if let id = editingId {
                    Section {
                        Button(role: .destructive) {
                            Task {
                                isSaving = true
                                let ok = await vm.delete(id: id)
                                isSaving = false
                                if ok { dismiss() }
                            }
                        } label: {
                            Text("부상 기록 삭제").frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle(editingId == nil ? "부상 등록" : "부상 수정")
            .navigationBarTitleDisplayMode(.inline)
            .alert(
                "처리 실패",
                isPresented: Binding(get: { vm.errorMessage != nil }, set: { if !$0 { vm.errorMessage = nil } })
            ) {
                Button("확인", role: .cancel) { vm.errorMessage = nil }
            } message: {
                Text(vm.errorMessage ?? "")
            }
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("취소") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("저장") { save() }
                        .disabled(playerId == 0 || isSaving)
                }
            }
        }
    }

    private func playerLabel(_ player: Player) -> String {
        player.number.map { "\(player.name) (\($0))" } ?? player.name
    }

    private func save() {
        let draft = InjuryDraft(
            id: editingId,
            playerId: playerId,
            type: type,
            startdate: DateFormats.day.string(from: startDate),
            returndate: hasReturned ? DateFormats.day.string(from: returnDate) : "",
            memo: memo
        )
        Task {
            isSaving = true
            let ok = await vm.save(draft)
            isSaving = false
            if ok { dismiss() }
        }
    }
}
