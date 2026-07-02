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

    private static let df: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    init(vm: InjuryViewModel, draft: InjuryDraft) {
        self.vm = vm
        self.editingId = draft.id
        _playerId = State(initialValue: draft.playerId)
        _type = State(initialValue: draft.type)
        _startDate = State(initialValue: Self.df.date(from: draft.startdate) ?? Date())
        _hasReturned = State(initialValue: !draft.returndate.isEmpty)
        _returnDate = State(initialValue: Self.df.date(from: draft.returndate) ?? Date())
        _memo = State(initialValue: draft.memo)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("선수") {
                    Picker("선수", selection: $playerId) {
                        ForEach(vm.players) { player in
                            Text(player.number.map { "\(player.name) (\($0))" } ?? player.name)
                                .tag(player.id)
                        }
                    }
                }

                Section("부상 정보") {
                    TextField("부상 부위/종류 (예: 발목 염좌)", text: $type)
                    DatePicker("발생일", selection: $startDate, in: ...Date(), displayedComponents: .date)
                    Toggle("복귀 완료", isOn: $hasReturned)
                    if hasReturned {
                        DatePicker("복귀일", selection: $returnDate, in: startDate..., displayedComponents: .date)
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
                                await vm.delete(id: id)
                                isSaving = false
                                dismiss()
                            }
                        } label: {
                            Text("부상 기록 삭제").frame(maxWidth: .infinity)
                        }
                    }
                }
            }
            .navigationTitle(editingId == nil ? "부상 등록" : "부상 수정")
            .navigationBarTitleDisplayMode(.inline)
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

    private func save() {
        let draft = InjuryDraft(
            id: editingId,
            playerId: playerId,
            type: type,
            startdate: Self.df.string(from: startDate),
            returndate: hasReturned ? Self.df.string(from: returnDate) : "",
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
