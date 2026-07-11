import SwiftUI

/// 훈련 등록/수정 시트 — 입력 필드는 일시 하나뿐(의도적 최소 설계). 참석 체크는 목록에서 한다.
struct TrainingFormView: View {
    @ObservedObject var vm: TrainingViewModel
    let draft: TrainingDraft

    @Environment(\.dismiss) private var dismiss
    @Environment(\.fsTheme) var t
    @State private var date: Date
    @State private var isSaving = false
    @State private var showDeleteConfirm = false

    private let editingId: Int?

    init(vm: TrainingViewModel, draft: TrainingDraft) {
        self.vm = vm
        self.draft = draft
        self.editingId = draft.id
        _date = State(initialValue: draft.date)
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
                    Text(editingId == nil ? "훈련 등록" : "훈련 수정")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(t.text)
                    Spacer()
                    Button { save() } label: {
                        Text("저장")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(isSaving ? t.textSec : t.accent)
                    }
                    .disabled(isSaving)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 32)

                VStack(spacing: 12) {
                    DatePicker("훈련 일시", selection: $date, displayedComponents: [.date, .hourAndMinute])
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(t.bgElev)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(t.line, lineWidth: 0.5))
                        .foregroundColor(t.text)

                    if editingId != nil {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Text("훈련 삭제")
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundColor(t.neg)
                                .frame(maxWidth: .infinity)
                                .frame(height: 52)
                                .background(t.bgElev)
                                .cornerRadius(10)
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(t.line, lineWidth: 0.5))
                        }
                        .disabled(isSaving)
                    }
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
        .confirmationDialog(
            "훈련 삭제",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) { deleteTraining() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("이 훈련과 참석 기록이 모두 삭제됩니다. 이 작업은 되돌릴 수 없습니다.")
        }
        .errorAlert($vm.errorMessage)
    }

    private func save() {
        isSaving = true
        Task {
            var updated = draft
            updated.date = date
            let ok = await vm.save(updated)
            isSaving = false
            if ok { dismiss() }
        }
    }

    private func deleteTraining() {
        guard let id = editingId else { return }
        isSaving = true
        Task {
            let ok = await vm.delete(id: id)
            isSaving = false
            if ok { dismiss() }
        }
    }
}
