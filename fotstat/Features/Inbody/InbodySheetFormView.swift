import SwiftUI

/// 엑셀 시트를 대체하는 팀 일괄 입력 시트 — 공통 검사일 1개 + 선수 카드별 측정값.
/// (player, testdate) upsert 라 같은 날짜로 재저장해도 값만 갱신된다.
/// 값이 하나라도 입력된 선수만 저장하고, 빈 행은 건드리지 않는다(삭제 아님).
struct InbodySheetFormView: View {
    @ObservedObject var vm: InbodyViewModel

    @Environment(\.dismiss) private var dismiss
    @Environment(\.fsTheme) var t
    @State private var testdate: Date = Date()
    @State private var drafts: [Int: InbodyDraft] = [:]   // playerId → 입력값
    @State private var isSaving = false
    /// 사용자가 시트에서 직접 값을 고쳤는가 — 날짜 변경으로 입력이 사라지기 전 확인용.
    /// (프리필된 기존 값만 있는 상태는 해당 없음)
    @State private var hasEdits = false
    @State private var pendingDate: Date? = nil

    init(vm: InbodyViewModel) {
        self.vm = vm
        _drafts = State(initialValue: Self.buildDrafts(vm: vm, ymd: Date.todayYMD))
    }

    /// 선택한 검사일에 이미 저장된 측정으로 행을 프리필한다.
    private static func buildDrafts(vm: InbodyViewModel, ymd: String) -> [Int: InbodyDraft] {
        Dictionary(uniqueKeysWithValues: vm.players.map { player in
            if let existing = vm.byPlayer[player.id]?.first(where: { $0.testdate == ymd }) {
                return (player.id, InbodyDraft.from(existing))
            }
            return (player.id, InbodyDraft(playerId: player.id, testdate: ymd))
        })
    }

    private var filledCount: Int {
        drafts.values.filter(\.hasValue).count
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
                    Text("인바디 입력")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(t.text)
                    Spacer()
                    FSSaveButton(isSaving: isSaving) { save() }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 14)

                HStack(spacing: 8) {
                    DatePicker(
                        "검사일",
                        selection: Binding(
                            get: { testdate },
                            set: { newValue in
                                // 입력 중이던 값이 있으면 날짜 변경으로 사라지므로 한 번 확인한다
                                if hasEdits {
                                    pendingDate = newValue
                                } else {
                                    applyDate(newValue)
                                }
                            }
                        ),
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .foregroundColor(t.text)
                    Spacer()
                    Text("입력 \(filledCount)/\(vm.players.count)명")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(t.textSec)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 6)

                Text("값이 입력된 선수만 저장됩니다. 같은 검사일에 다시 저장하면 값이 갱신됩니다.")
                    .font(.system(size: 11))
                    .foregroundColor(t.textTer)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 24)
                    .padding(.bottom, 8)

                ScrollView {
                    LazyVStack(spacing: 10) {
                        ForEach(vm.players) { player in
                            playerCard(player)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .confirmationDialog(
            "검사일 변경",
            isPresented: Binding(
                get: { pendingDate != nil },
                set: { if !$0 { pendingDate = nil } }
            ),
            titleVisibility: .visible,
            presenting: pendingDate
        ) { date in
            Button("변경", role: .destructive) { applyDate(date) }
            Button("취소", role: .cancel) {}
        } message: { _ in
            Text("검사일을 바꾸면 입력 중인 값이 사라집니다. 계속할까요?")
        }
        .errorAlert($vm.errorMessage)
        .interactiveDismissDisabled(isSaving)
    }

    /// 검사일을 바꾸고 해당 날짜의 기존 값으로 시트를 다시 채운다 (입력 중 값은 버려짐).
    private func applyDate(_ date: Date) {
        testdate = date
        drafts = Self.buildDrafts(vm: vm, ymd: DateFormats.day.string(from: date))
        hasEdits = false
        pendingDate = nil
    }

    private func playerCard(_ player: Player) -> some View {
        let hasValue = drafts[player.id]?.hasValue ?? false
        return VStack(spacing: 8) {
            HStack(spacing: 8) {
                FSPlayerAvatar(number: player.number, size: 26)
                Text(player.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(t.text)
                Spacer()
                if hasValue {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 14))
                        .foregroundColor(t.accent)
                }
            }
            InbodyFieldGrid(
                draft: Binding(
                    get: {
                        drafts[player.id]
                            ?? InbodyDraft(playerId: player.id, testdate: DateFormats.day.string(from: testdate))
                    },
                    set: {
                        drafts[player.id] = $0
                        hasEdits = true
                    }
                ),
                small: true
            )
        }
        .padding(12)
        .background(t.bgElev)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.line, lineWidth: 0.5))
    }

    private func save() {
        isSaving = true
        let ymd = DateFormats.day.string(from: testdate)
        let rows = vm.players.compactMap { drafts[$0.id] }
        Task {
            let ok = await vm.saveBatch(testdate: ymd, drafts: rows)
            isSaving = false
            if ok { dismiss() }
        }
    }
}
