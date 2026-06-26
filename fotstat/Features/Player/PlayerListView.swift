import SwiftUI

struct PlayerListView: View {
    @StateObject private var vm: PlayerViewModel
    @State private var showAddPlayer = false
    @State private var editingPlayer: Player?
    @Environment(\.fsTheme) var t

    init(team: Team) {
        _vm = StateObject(wrappedValue: PlayerViewModel(team: team))
    }

    // 포지션 그룹
    private func group(_ pos: String) -> String {
        switch pos {
        case "GK": return "GK"
        case "CB","LB","RB": return "DF"
        case "CDM","CM","CAM": return "MF"
        default: return "FW"
        }
    }

    private var groupOrder: [String] { ["GK","DF","MF","FW"] }
    private var groupLabels: [String: String] { ["GK":"골키퍼","DF":"수비수","MF":"미드필더","FW":"공격수"] }

    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 0) {
                    FSTeamHeader(team: vm.team, tab: .squad)

                    if vm.isLoading {
                        ProgressView().padding(.top, 80)
                    } else {
                        // 포지션별 그룹
                        ForEach(groupOrder, id: \.self) { grp in
                            let players = vm.players.filter { group($0.pos ?? "") == grp }
                            if !players.isEmpty {
                                VStack(spacing: 0) {
                                    HStack(spacing: 6) {
                                        Text(groupLabels[grp] ?? grp)
                                            .font(.system(size: 11, weight: .bold))
                                            .kerning(0.5)
                                            .textCase(.uppercase)
                                            .foregroundColor(t.textSec)
                                        Text("\(players.count)")
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .foregroundColor(t.textTer)
                                            .padding(.horizontal, 6).padding(.vertical, 1)
                                            .background(t.bgElev3).cornerRadius(4)
                                    }
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 12).padding(.bottom, 4)

                                    VStack(spacing: 0) {
                                        ForEach(Array(players.enumerated()), id: \.element.id) { i, player in
                                            PlayerRow(player: player)
                                                .contentShape(Rectangle())
                                                .onTapGesture { editingPlayer = player }
                                            if i < players.count - 1 {
                                                Divider().padding(.leading, 56).background(t.line)
                                            }
                                        }
                                    }
                                    .background(t.bgElev)
                                    .cornerRadius(12)
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.line, lineWidth: 0.5))
                                    .padding(.horizontal, 16)
                                }
                            }
                        }

                    }
                }
                .padding(.bottom, 100)
            }

            // FAB
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button { showAddPlayer = true } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 22, weight: .bold))
                            .foregroundColor(.white)
                            .frame(width: 56, height: 56)
                            .background(t.accent)
                            .clipShape(Circle())
                            .shadow(color: t.accent.opacity(0.4), radius: 12, x: 0, y: 6)
                    }
                    .padding(.trailing, 24)
                    .padding(.bottom, 32)
                }
            }
        }
        .background(t.bg.ignoresSafeArea())
        .task { await vm.fetchPlayers() }
        .sheet(isPresented: $showAddPlayer) {
            PlayerFormView(title: "선수 추가") { name, number, pos, birthdate in
                Task { await vm.createPlayer(name: name, number: number, pos: pos, birthdate: birthdate) }
            }
            .environment(\.fsTheme, t)
        }
        .sheet(item: $editingPlayer) { player in
            PlayerFormView(title: "선수 수정", initialName: player.name, initialNumber: player.number, initialPos: player.pos, initialBirthdate: player.birthdate) { name, number, pos, birthdate in
                Task { await vm.updatePlayer(id: player.id, name: name, number: number, pos: pos, birthdate: birthdate) }
            }
            .environment(\.fsTheme, t)
        }
    }
}

struct PlayerRow: View {
    let player: Player
    @Environment(\.fsTheme) var t

    var body: some View {
        HStack {
            Text("\(player.number ?? 0)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundColor(t.textSec)
                .frame(width: 32, alignment: .leading)

            HStack(spacing: 8) {
                Text(player.name)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundColor(t.text)
                if let pos = player.pos {
                    FSPosChip(pos: pos)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Image(systemName: "chevron.right")
                .font(.system(size: 12))
                .foregroundColor(t.textTer)
        }
        .padding(.horizontal, 12).padding(.vertical, 13)
    }
}
