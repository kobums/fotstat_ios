import SwiftUI

struct PlayerStatDetailView: View {
    let player: PlayerStats
    let allPlayers: [PlayerStats]
    @Environment(\.fsTheme) var t
    @Environment(\.dismiss) var dismiss

    private func avg(_ kp: KeyPath<PlayerStats, Int>) -> Double {
        guard !allPlayers.isEmpty else { return 0 }
        return Double(allPlayers.reduce(0) { $0 + $1[keyPath: kp] }) / Double(allPlayers.count)
    }

    // 상위 X%: X = (rank / total) * 100, rank 1 = 상위 X%가 가장 낮음
    private func topPct(_ kp: KeyPath<PlayerStats, Int>) -> Int {
        let v = player[keyPath: kp]
        let total = allPlayers.count
        guard total > 0 else { return 100 }
        let better = allPlayers.filter { $0[keyPath: kp] > v }.count
        return max(1, Int(ceil(Double(better + 1) / Double(total) * 100)))
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule().fill(t.textTer).frame(width: 36, height: 4)
                .padding(.top, 12).padding(.bottom, 20)

            // 선수 헤더
            HStack(spacing: 14) {
                FSPlayerAvatar(number: player.number, size: 52)
                VStack(alignment: .leading, spacing: 6) {
                    Text(player.name)
                        .font(.system(size: 22, weight: .black))
                        .foregroundColor(t.text)
                    if let pos = player.position { FSPosChip(pos: pos) }
                }
                Spacer()
                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundColor(t.textSec)
                        .frame(width: 28, height: 28)
                        .background(t.bgElev3)
                        .clipShape(Circle())
                }
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 24)

            // 미니 스탯 타일
            HStack(spacing: 8) {
                miniTile("골", value: player.goal, accent: true)
                miniTile("도움", value: player.assist)
                miniTile("출전 분", value: player.min, suffix: "'")
                miniTile("경기", value: player.games)
            }
            .padding(.horizontal, 16)
            .padding(.bottom, 20)

            // 팀 평균 비교
            VStack(spacing: 0) {
                HStack {
                    Text("팀 평균 비교")
                        .font(.system(size: 11, weight: .bold))
                        .kerning(0.5)
                        .foregroundColor(t.textTer)
                    Spacer()
                    HStack(spacing: 6) {
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2).fill(t.accent).frame(width: 12, height: 4)
                            Text("이 선수").font(.system(size: 10)).foregroundColor(t.textSec)
                        }
                        HStack(spacing: 4) {
                            RoundedRectangle(cornerRadius: 2).fill(t.bgElev3).frame(width: 12, height: 4)
                            Text("팀 평균").font(.system(size: 10)).foregroundColor(t.textTer)
                        }
                    }
                }
                .padding(.horizontal, 14).padding(.vertical, 10)
                .overlay(Rectangle().fill(t.line).frame(height: 0.5), alignment: .bottom)

                compRow(label: "골", kp: \.goal, suffix: "G", accent: true)
                Divider().background(t.line)
                compRow(label: "도움", kp: \.assist, suffix: "A")
                Divider().background(t.line)
                compRow(label: "출전 시간", kp: \.min, suffix: "'")
            }
            .background(t.bgElev)
            .cornerRadius(14)
            .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.line, lineWidth: 0.5))
            .padding(.horizontal, 16)

            Spacer()
        }
        .background(t.bg.ignoresSafeArea())
        .presentationDetents([.fraction(0.72)])
        .presentationDragIndicator(.hidden)
    }

    @ViewBuilder
    private func miniTile(_ label: String, value: Int, suffix: String = "", accent: Bool = false) -> some View {
        VStack(spacing: 4) {
            Text("\(value)\(suffix)")
                .font(.system(size: 22, weight: .black, design: .rounded))
                .foregroundColor(accent && value > 0 ? t.accent : t.text)
                .minimumScaleFactor(0.6)
            Text(label)
                .font(.system(size: 10, weight: .bold))
                .kerning(0.4)
                .foregroundColor(t.textTer)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(t.bgElev)
        .cornerRadius(12)
        .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.line, lineWidth: 0.5))
    }

    @ViewBuilder
    private func compRow(label: String, kp: KeyPath<PlayerStats, Int>, suffix: String, accent: Bool = false) -> some View {
        let val = Double(player[keyPath: kp])
        let avgVal = avg(kp)
        let pct = topPct(kp)
        let maxBar = max(val, avgVal, 1.0)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(label)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(t.text)
                Spacer()
                Text("\(Int(val))\(suffix)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(accent ? t.accent : t.text)
                Text("·")
                    .font(.system(size: 11))
                    .foregroundColor(t.textTer)
                Text(avgVal.truncatingRemainder(dividingBy: 1) < 0.05
                     ? "\(Int(avgVal))\(suffix)"
                     : String(format: "%.1f\(suffix)", avgVal))
                    .font(.system(size: 13, design: .rounded))
                    .foregroundColor(t.textSec)
                Text("상위 \(pct)%")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(t.accent)
                    .padding(.horizontal, 6).padding(.vertical, 2)
                    .background(t.accentSoft).cornerRadius(4)
            }
            GeometryReader { geo in
                VStack(spacing: 3) {
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(t.bgElev3).frame(height: 5)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(accent ? t.accent : t.text.opacity(0.5))
                            .frame(width: geo.size.width * CGFloat(val / maxBar), height: 5)
                    }
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3).fill(t.bgElev3).frame(height: 5)
                        RoundedRectangle(cornerRadius: 3)
                            .fill(t.textTer)
                            .frame(width: geo.size.width * CGFloat(avgVal / maxBar), height: 5)
                    }
                }
            }
            .frame(height: 13)
        }
        .padding(.horizontal, 14).padding(.vertical, 12)
    }
}
