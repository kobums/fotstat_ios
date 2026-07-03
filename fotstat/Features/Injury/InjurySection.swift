import SwiftUI

/// 팀 홈의 "부상자 명단" 섹션. 현재 부상 중인 선수를 카드로 보여주고,
/// 행 탭 시 수정, 헤더의 + 로 신규 등록 폼을 연다. 결장 경기 수는 팀 경기(matches)와
/// 부상 기간을 대조해 계산한다.
struct InjurySection: View {
    @ObservedObject var vm: InjuryViewModel
    let matches: [Match]
    @Environment(\.fsTheme) var t

    @State private var editing: InjuryDraft? = nil

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("부상자 명단")
                    .font(.system(size: 13, weight: .bold))
                    .kerning(0.6)
                    .foregroundColor(t.textSec)
                Spacer()
                Button {
                    let firstPlayer = vm.players.first?.id ?? 0
                    editing = .new(playerId: firstPlayer, today: Self.todayString())
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundColor(t.accent)
                        .frame(width: 28, height: 28)
                }
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            let active = vm.activeInjuries
            if active.isEmpty {
                Text("현재 부상 중인 선수가 없습니다")
                    .font(.system(size: 13))
                    .foregroundColor(t.textSec)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                VStack(spacing: 0) {
                    ForEach(Array(active.enumerated()), id: \.element.id) { i, injury in
                        Button {
                            editing = .from(injury)
                        } label: {
                            InjuryRow(
                                name: vm.playerName(for: injury.player),
                                number: vm.playerNumber(for: injury.player),
                                type: injury.type,
                                startdate: String((injury.startdate ?? "").prefix(10)),
                                absentGames: vm.absentGames(for: injury, matches: matches)
                            )
                        }
                        .buttonStyle(.plain)
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
        }
        .sheet(item: $editing) { draft in
            InjuryFormView(vm: vm, draft: draft)
                .environment(\.fsTheme, t)
        }
        // 시트가 열려 있을 땐 폼 쪽 alert가 처리하므로 여기서는 닫힌 상태의 조회 실패만 노출
        .alert(
            "불러오기 실패",
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

    private static func todayString() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: Date())
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
    @Environment(\.fsTheme) var t

    var body: some View {
        HStack(spacing: 10) {
            FSPlayerAvatar(number: number, size: 34)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(name).font(.system(size: 14, weight: .bold)).foregroundColor(t.text)
                    Text("부상")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(t.neg)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(t.neg.opacity(0.13))
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
                    Text("\(startdate)~").font(.system(size: 10)).foregroundColor(t.textTer)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
