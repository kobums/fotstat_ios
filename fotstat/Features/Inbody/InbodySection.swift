import SwiftUI

/// "인바디" 섹션 — 선수단 탭에 삽입된다. 측정이 있는 선수의 최신값을 카드로
/// 보여주고, 행 탭으로 선수별 이력·추이(PlayerInbodyView), 헤더 버튼으로
/// 시트형 일괄 입력(InbodySheetFormView)을 연다.
struct InbodySection: View {
    @ObservedObject var vm: InbodyViewModel
    @Environment(\.fsTheme) var t

    @State private var showSheetInput = false
    @State private var viewingPlayerId: Int? = nil
    // 이력이 쌓이면 선수 목록을 밀어내므로 기본 접힘
    @State private var expanded = false

    /// 측정이 있는 선수의 (선수, 최신 측정) — 최신 검사일 순.
    private var measured: [(player: Player, latest: Inbody)] {
        vm.players.compactMap { player in
            vm.latest(for: player.id).map { (player, $0) }
        }
        .sorted { $0.latest.testdate > $1.latest.testdate }
    }

    var body: some View {
        VStack(spacing: 0) {
            HStack {
                Text("인바디")
                    .font(.system(size: 13, weight: .bold))
                    .kerning(0.6)
                    .foregroundColor(t.textSec)
                if !measured.isEmpty {
                    Text("\(measured.count)")
                        .font(.system(size: 12, weight: .bold, design: .rounded))
                        .foregroundColor(t.textTer)
                }
                Spacer()
                Button {
                    showSheetInput = true
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "square.and.pencil")
                            .font(.system(size: 11, weight: .bold))
                        Text("시트 입력")
                            .font(.system(size: 12, weight: .bold))
                    }
                    .foregroundColor(t.accent)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(t.bgElev3)
                    .cornerRadius(8)
                }
                .disabled(vm.players.isEmpty)
            }
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 8)

            if measured.isEmpty {
                Text("측정 기록이 없습니다. 시트 입력으로 팀 전체를 한 번에 기록하세요.")
                    .font(.system(size: 13))
                    .foregroundColor(t.textSec)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
            } else {
                let visible = expanded ? measured : Array(measured.prefix(3))
                VStack(spacing: 0) {
                    ForEach(Array(visible.enumerated()), id: \.element.player.id) { i, row in
                        Button {
                            viewingPlayerId = row.player.id
                        } label: {
                            InbodyRow(player: row.player, latest: row.latest)
                        }
                        .buttonStyle(.plain)
                        if i < visible.count - 1 {
                            Divider().background(t.line)
                        }
                    }

                    if measured.count > 3 {
                        Divider().background(t.line)
                        Button {
                            withAnimation(.easeInOut(duration: 0.2)) { expanded.toggle() }
                        } label: {
                            HStack(spacing: 4) {
                                Text(expanded ? "접기" : "전체 보기 (\(measured.count)명)")
                                    .font(.system(size: 12, weight: .semibold))
                                Image(systemName: "chevron.down")
                                    .font(.system(size: 10, weight: .semibold))
                                    .rotationEffect(.degrees(expanded ? 180 : 0))
                            }
                            .foregroundColor(t.textSec)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 10)
                            .contentShape(Rectangle())
                        }
                        .buttonStyle(.plain)
                    }
                }
                .fsCard()
                .padding(.horizontal, 16)
            }
        }
        .sheet(isPresented: $showSheetInput) {
            InbodySheetFormView(vm: vm)
                .environment(\.fsTheme, t)
        }
        .sheet(item: Binding(
            get: { viewingPlayerId.map(ViewingPlayer.init) },
            set: { viewingPlayerId = $0?.id }
        )) { viewing in
            PlayerInbodyView(vm: vm, playerId: viewing.id)
                .environment(\.fsTheme, t)
        }
        // 시트가 열려 있을 땐 시트 쪽 alert가 처리하므로 닫힌 상태의 실패(조회)만 노출
        .errorAlert($vm.errorMessage, enabled: !showSheetInput && viewingPlayerId == nil)
    }
}

/// sheet(item:) 용 래퍼 — 선수 id 하나를 Identifiable 로 만든다.
private struct ViewingPlayer: Identifiable {
    let id: Int
}

private struct InbodyRow: View {
    let player: Player
    let latest: Inbody
    @Environment(\.fsTheme) var t

    var body: some View {
        HStack(spacing: 10) {
            FSPlayerAvatar(number: player.number, size: 34)

            VStack(alignment: .leading, spacing: 3) {
                Text(player.name)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(t.text)
                Text(latest.testdate)
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(t.textTer)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            VStack(alignment: .trailing, spacing: 2) {
                Text("체중 \(inbodyValue(latest.weight, unit: "kg")) · 체지방 \(inbodyValue(latest.fat, unit: "%"))")
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundColor(t.text)
                Text("점수 \(inbodyValue(latest.score))")
                    .font(.system(size: 10, design: .rounded))
                    .foregroundColor(t.textTer)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
