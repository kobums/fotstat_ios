import SwiftUI

/// 참석 체크 시트 — 선수별 체크 + 훈련 시간(분)을 배치로 저장한다.
/// 체크 = upsert, 해제 = 삭제. 부상 기간에 걸친 선수는 비활성(백엔드도 거부).
struct AttendanceFormView: View {
    @ObservedObject var vm: TrainingViewModel
    let training: Training

    @Environment(\.dismiss) private var dismiss
    @Environment(\.fsTheme) var t
    @State private var drafts: [Int: Draft] = [:]   // playerId → 입력값
    @State private var isSaving = false

    private static let defaultMin = 60

    struct Draft {
        var checked: Bool
        var min: Int
    }

    init(vm: TrainingViewModel, training: Training) {
        self.vm = vm
        self.training = training
        let existing = Self.existingByPlayer(vm: vm, trainingId: training.id)
        _drafts = State(initialValue: Dictionary(
            uniqueKeysWithValues: vm.players.map { player in
                let a = existing[player.id]
                return (player.id, Draft(checked: a != nil, min: a?.min ?? Self.defaultMin))
            }
        ))
    }

    /// 이 훈련의 기존 참석을 playerId 로 조회하는 맵.
    private static func existingByPlayer(vm: TrainingViewModel, trainingId: Int) -> [Int: Attendance] {
        Dictionary(
            vm.attendances(for: trainingId).map { ($0.player, $0) },
            uniquingKeysWith: { a, _ in a }
        )
    }

    private var dateString: String {
        guard let d = training.parsedDate else { return training.trainingdate }
        let f = DateFormatter()
        f.dateFormat = "M월 d일 (E) · HH:mm"
        f.locale = Locale(identifier: "ko_KR")
        return f.string(from: d)
    }

    private var checkedCount: Int {
        drafts.values.filter(\.checked).count
    }

    var body: some View {
        let injuredIds = vm.injuredPlayerIds(on: training.trainingdate)
        ZStack {
            t.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Text("취소").foregroundColor(t.textSec)
                    }
                    Spacer()
                    Text("참석 체크")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(t.text)
                    Spacer()
                    FSSaveButton(isSaving: isSaving) { save() }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 14)

                HStack {
                    Text(dateString)
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(t.text)
                    Spacer()
                    Text("참석 \(checkedCount)/\(vm.players.count)명")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(t.textSec)
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 10)

                ScrollView {
                    VStack(spacing: 0) {
                        ForEach(Array(vm.players.enumerated()), id: \.element.id) { i, player in
                            playerRow(player, injuredIds: injuredIds)
                            if i < vm.players.count - 1 {
                                Divider().background(t.line)
                            }
                        }
                    }
                    .fsCard()
                    .padding(.horizontal, 16)
                    .padding(.bottom, 20)
                }
            }
        }
        .errorAlert($vm.errorMessage)
        .interactiveDismissDisabled(isSaving)
    }

    @ViewBuilder
    private func playerRow(_ player: Player, injuredIds: Set<Int>) -> some View {
        let draft = drafts[player.id] ?? Draft(checked: false, min: Self.defaultMin)
        let injured = injuredIds.contains(player.id)
        // 부상 중이라도 기존 참석(부상 등록 전 입력)은 해제할 수 있어야 한다
        let disabled = injured && !draft.checked

        HStack(spacing: 10) {
            Button {
                drafts[player.id, default: draft].checked.toggle()
            } label: {
                HStack(spacing: 10) {
                    Image(systemName: draft.checked ? "checkmark.circle.fill" : "circle")
                        .font(.system(size: 20))
                        .foregroundColor(draft.checked ? t.accent : t.textTer)

                    FSPlayerAvatar(number: player.number, size: 30)

                    Text(player.name)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundColor(t.text)
                        .lineLimit(1)

                    if injured {
                        Text("부상 중")
                            .font(.system(size: 10, weight: .black))
                            .foregroundColor(t.neg)
                            .padding(.horizontal, 5).padding(.vertical, 2)
                            .background(t.neg.opacity(0.13))
                            .cornerRadius(4)
                    }

                    Spacer(minLength: 0)
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .disabled(disabled)
            .opacity(disabled ? 0.45 : 1)

            if draft.checked {
                FSStepper(
                    value: draft.min,
                    suffix: "분",
                    small: true,
                    canIncrement: draft.min < 300,
                    onDecrement: { drafts[player.id, default: draft].min = max(0, draft.min - 5) },
                    onIncrement: { drafts[player.id, default: draft].min = min(300, draft.min + 5) }
                )
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
    }

    private func save() {
        let existing = Self.existingByPlayer(vm: vm, trainingId: training.id)
        var upserts: [(player: Int, min: Int)] = []
        var deletes: [Int] = []
        for player in vm.players {
            guard let draft = drafts[player.id] else { continue }
            let before = existing[player.id]
            if draft.checked {
                // upsert — 신규 체크와 min 변경 모두 batch insert 한 번으로 처리된다
                if before == nil || before?.min != draft.min {
                    upserts.append((player: player.id, min: draft.min))
                }
            } else if let before {
                deletes.append(before.id)
            }
        }

        isSaving = true
        Task {
            let ok = await vm.saveAttendances(trainingId: training.id, upserts: upserts, deletes: deletes)
            isSaving = false
            if ok { dismiss() }
        }
    }
}
