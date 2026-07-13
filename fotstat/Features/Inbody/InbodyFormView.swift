import SwiftUI

/// 측정 1건 등록/수정 시트 — 검사일만 필수, 나머지는 빈칸 = 미측정.
struct InbodyFormView: View {
    @ObservedObject var vm: InbodyViewModel
    let draft: InbodyDraft

    @Environment(\.dismiss) private var dismiss
    @Environment(\.fsTheme) var t
    @State private var testdate: Date
    @State private var values: InbodyDraft
    @State private var isSaving = false
    @State private var showDeleteConfirm = false

    private let editingId: Int?

    init(vm: InbodyViewModel, draft: InbodyDraft) {
        self.vm = vm
        self.draft = draft
        self.editingId = draft.id
        _testdate = State(initialValue: DateFormats.day.date(from: draft.testdate) ?? Date())
        _values = State(initialValue: draft)
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
                    Text(editingId == nil ? "측정 추가" : "측정 수정")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(t.text)
                    Spacer()
                    FSSaveButton(isSaving: isSaving) { save() }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 20)

                ScrollView {
                    VStack(spacing: 12) {
                        Text(vm.playerName(for: draft.playerId))
                            .font(.system(size: 14, weight: .bold))
                            .foregroundColor(t.text)
                            .frame(maxWidth: .infinity, alignment: .leading)

                        DatePicker("검사일", selection: $testdate, in: ...Date(), displayedComponents: .date)
                            .padding(.horizontal, 16)
                            .frame(height: 52)
                            .background(t.bgElev)
                            .cornerRadius(10)
                            .overlay(RoundedRectangle(cornerRadius: 10).stroke(t.line, lineWidth: 0.5))
                            .foregroundColor(t.text)

                        InbodyFieldGrid(draft: $values)

                        if editingId != nil {
                            Button(role: .destructive) {
                                showDeleteConfirm = true
                            } label: {
                                Text("측정 기록 삭제")
                                    .font(.system(size: 15, weight: .semibold))
                                    .foregroundColor(t.neg)
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 52)
                                    .background(t.bgElev)
                                    .cornerRadius(10)
                                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(t.line, lineWidth: 0.5))
                            }
                            .disabled(isSaving)
                            .padding(.top, 8)
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 24)
                }
            }
        }
        .confirmationDialog(
            "측정 기록 삭제",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) { deleteInbody() }
            Button("취소", role: .cancel) {}
        } message: {
            Text("이 측정 기록이 삭제됩니다. 이 작업은 되돌릴 수 없습니다.")
        }
        .errorAlert($vm.errorMessage)
        .interactiveDismissDisabled(isSaving)
    }

    private func save() {
        isSaving = true
        Task {
            var updated = values
            updated.testdate = DateFormats.day.string(from: testdate)
            let ok = await vm.save(updated)
            isSaving = false
            if ok { dismiss() }
        }
    }

    private func deleteInbody() {
        guard let id = editingId else { return }
        isSaving = true
        Task {
            let ok = await vm.delete(id: id)
            isSaving = false
            if ok { dismiss() }
        }
    }
}

// MARK: - InbodyFieldGrid (측정값 2열 입력 그리드 — 폼·시트 공용)

struct InbodyFieldGrid: View {
    @Binding var draft: InbodyDraft
    var small: Bool = false
    @Environment(\.fsTheme) var t

    var body: some View {
        VStack(spacing: small ? 6 : 10) {
            HStack(spacing: small ? 6 : 10) {
                field("신장(cm)", $draft.height)
                field("체중(kg)", $draft.weight)
            }
            HStack(spacing: small ? 6 : 10) {
                field("골격근량(kg)", $draft.muscle)
                field("체지방률(%)", $draft.fat)
            }
            HStack(spacing: small ? 6 : 10) {
                field("오른다리(kg)", $draft.rightleg)
                field("왼다리(kg)", $draft.leftleg)
            }
            HStack(spacing: small ? 6 : 10) {
                field("인바디 점수", $draft.score)
                Color.clear.frame(maxWidth: .infinity, maxHeight: 1)
            }
        }
    }

    private func field(_ label: String, _ text: Binding<String>) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.system(size: small ? 10 : 11, weight: .semibold))
                .foregroundColor(t.textSec)
            TextField("-", text: text)
                .keyboardType(.decimalPad)
                .font(.system(size: small ? 14 : 16, design: .rounded))
                .foregroundColor(t.text)
                .multilineTextAlignment(.trailing)
                .padding(.horizontal, 10)
                .frame(height: small ? 34 : 44)
                .background(t.bgElev)
                .cornerRadius(8)
                .overlay(RoundedRectangle(cornerRadius: 8).stroke(t.line, lineWidth: 0.5))
        }
        .frame(maxWidth: .infinity)
    }
}
