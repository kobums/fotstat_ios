import SwiftUI

/// "부상자 명단" 섹션. 현재 부상 중인 선수를 카드로 보여준다.
/// 기본(선수단 탭)은 행 탭 시 수정, 헤더의 + 로 신규 등록 폼을 연다.
/// isReadOnly(팀 홈)면 표시 전용 — +/행 탭이 없고 부상자가 없으면 섹션 자체를 숨긴다.
/// 결장 경기 수는 팀 경기(vm.matches)와 부상 기간을 대조해 계산한다.
struct InjurySection: View {
    @ObservedObject var vm: InjuryViewModel
    var isReadOnly: Bool = false
    @Environment(\.fsTheme) var t

    @State private var editing: InjuryDraft? = nil
    @State private var returning: Injury? = nil
    // 지난 부상은 이력이 쌓이면 선수 목록을 밀어내므로 기본 접힘
    @State private var showPast = false

    var body: some View {
        let active = vm.activeInjuries
        VStack(spacing: 0) {
            if !(isReadOnly && active.isEmpty) {
                HStack {
                    Text("부상자 명단")
                        .font(.system(size: 13, weight: .bold))
                        .kerning(0.6)
                        .foregroundColor(t.textSec)
                    Spacer()
                    if !isReadOnly {
                        Button {
                            editing = .new(playerId: vm.defaultNewInjuryPlayerId, startdate: Date.todayYMD)
                        } label: {
                            Image(systemName: "plus")
                                .font(.system(size: 13, weight: .bold))
                                .foregroundColor(t.accent)
                                .frame(width: 28, height: 28)
                        }
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)

                if active.isEmpty {
                    Text("현재 부상 중인 선수가 없습니다")
                        .font(.system(size: 13))
                        .foregroundColor(t.textSec)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                } else {
                    VStack(spacing: 0) {
                        ForEach(Array(active.enumerated()), id: \.element.id) { i, injury in
                            let row = InjuryRow(
                                name: vm.playerName(for: injury.player),
                                number: vm.playerNumber(for: injury.player),
                                type: injury.type,
                                startdate: (injury.startdate ?? "").dayPrefix,
                                absentGames: vm.absentGames(for: injury, matches: vm.matches)
                            )
                            if isReadOnly {
                                row
                            } else {
                                HStack(spacing: 0) {
                                    Button {
                                        editing = .from(injury)
                                    } label: {
                                        row
                                    }
                                    .buttonStyle(.plain)

                                    // 원탭 복귀 처리 — 복귀일을 오늘로 종료
                                    Button {
                                        returning = injury
                                    } label: {
                                        Text("복귀")
                                            .font(.system(size: 12, weight: .bold))
                                            .foregroundColor(t.accent)
                                            .padding(.horizontal, 12)
                                            .padding(.vertical, 7)
                                            .background(t.bgElev3)
                                            .cornerRadius(8)
                                    }
                                    .buttonStyle(.plain)
                                    .padding(.trailing, 12)
                                }
                            }
                            if i < active.count - 1 {
                                Divider().background(t.line)
                            }
                        }
                    }
                    .background(t.bgElev)
                    .cornerRadius(12)
                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.line, lineWidth: 0.5))
                    .padding(.horizontal, 16)
                }

                // 지난 부상 이력 — 선수단 탭(편집 가능)에서만 노출. 홈 탭은 부상 중만 보여준다.
                if !isReadOnly && !vm.pastInjuries.isEmpty {
                    pastList
                }
            }
        }
        .confirmationDialog(
            "복귀 처리",
            isPresented: Binding(
                get: { returning != nil },
                set: { if !$0 { returning = nil } }
            ),
            titleVisibility: .visible,
            presenting: returning
        ) { injury in
            Button("복귀") {
                Task { _ = await vm.endInjury(injury) }
            }
            Button("취소", role: .cancel) {}
        } message: { injury in
            Text("'\(vm.playerName(for: injury.player))' 선수의 복귀일을 오늘로 설정합니다. 날짜를 바꾸려면 항목을 눌러 수정하세요.")
        }
        .sheet(item: $editing) { draft in
            InjuryFormView(vm: vm, draft: draft)
                .environment(\.fsTheme, t)
        }
        // 시트가 열려 있을 땐 폼 쪽 alert가 처리하므로 여기서는 닫힌 상태의 실패(조회·복귀 처리)만 노출
        .alert(
            "오류",
            isPresented: Binding(
                get: { vm.errorMessage != nil && editing == nil },
                set: { if !$0 { vm.errorMessage = nil } }
            )
        ) {
            Button("확인", role: .cancel) { vm.errorMessage = nil }
        } message: {
            Text(vm.errorMessage ?? "")
        }
    }

    /// "지난 부상" 서브섹션 — 복귀가 끝난 이력을 최신순으로, 탭하면 수정.
    /// 기본은 접힘 상태로 건수만 보여주고, 헤더 탭으로 펼친다.
    private var pastList: some View {
        let past = vm.pastInjuries
        return VStack(spacing: 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) { showPast.toggle() }
            } label: {
                HStack(spacing: 6) {
                    Text("지난 부상")
                        .font(.system(size: 13, weight: .bold))
                        .kerning(0.6)
                        .foregroundColor(t.textSec)
                    Text("\(past.count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(t.textTer)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundColor(t.textTer)
                        .rotationEffect(.degrees(showPast ? 90 : 0))
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)
                .padding(.bottom, 8)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)
            .accessibilityValue(showPast ? "펼쳐짐" : "접힘")

            if showPast {
                pastRows(past)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func pastRows(_ past: [Injury]) -> some View {
        VStack(spacing: 0) {
            ForEach(Array(past.enumerated()), id: \.element.id) { i, injury in
                Button {
                    editing = .from(injury)
                } label: {
                    InjuryRow(
                        name: vm.playerName(for: injury.player),
                        number: vm.playerNumber(for: injury.player),
                        type: injury.type,
                        startdate: (injury.startdate ?? "").dayPrefix,
                        absentGames: vm.absentGames(for: injury, matches: vm.matches),
                        returndate: (injury.returndate ?? "").dayPrefix
                    )
                }
                .buttonStyle(.plain)
                if i < past.count - 1 {
                    Divider().background(t.line)
                }
            }
        }
        .background(t.bgElev)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.line, lineWidth: 0.5))
        .padding(.horizontal, 16)
    }
}

// InjuryDraft 를 sheet(item:)에 쓰기 위한 Identifiable 준수.
// 저장된 id(Int?) 가 식별자 역할을 한다(신규는 nil).
extension InjuryDraft: Identifiable {}

private struct InjuryRow: View {
    let name: String
    let number: Int?
    let type: String?
    let startdate: String
    let absentGames: Int
    /// 비어 있지 않으면 지난 부상(복귀 완료) 행 — "복귀" 배지와 기간(발생~복귀)을 표시
    var returndate: String = ""
    @Environment(\.fsTheme) var t

    private var isPast: Bool { !returndate.isEmpty }

    var body: some View {
        HStack(spacing: 10) {
            FSPlayerAvatar(number: number, size: 34)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(name).font(.system(size: 14, weight: .bold)).foregroundColor(t.text)
                    Text(isPast ? "복귀" : "부상")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(isPast ? t.pos : t.neg)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background((isPast ? t.pos : t.neg).opacity(0.13))
                        .cornerRadius(4)
                }
                if let type, !type.isEmpty {
                    Text(type).font(.system(size: 11)).foregroundColor(t.textSec)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 2) {
                Text("결장 \(absentGames)경기")
                    .font(.system(size: 12, weight: .bold, design: .rounded))
                    .foregroundColor(t.text)
                if !startdate.isEmpty {
                    Text("\(startdate)~\(returndate)").font(.system(size: 10)).foregroundColor(t.textTer)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
