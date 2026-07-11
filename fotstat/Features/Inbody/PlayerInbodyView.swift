import SwiftUI

/// 선수별 인바디 이력 시트 — 최신 측정 요약 + 추이 차트 + 이력 리스트.
/// 행 탭 = 수정, 컨텍스트 메뉴 = 삭제, 상단 + = 측정 추가.
struct PlayerInbodyView: View {
    @ObservedObject var vm: InbodyViewModel
    let playerId: Int

    @Environment(\.dismiss) private var dismiss
    @Environment(\.fsTheme) var t
    @State private var editing: InbodyDraft? = nil
    @State private var deleting: Inbody? = nil
    @State private var metric: Metric = .weight

    enum Metric: String, CaseIterable, Identifiable {
        case weight = "체중"
        case fat = "체지방률"
        case muscle = "골격근량"
        var id: String { rawValue }

        var unit: String {
            switch self {
            case .weight, .muscle: return "kg"
            case .fat: return "%"
            }
        }

        func value(of e: Inbody) -> Double {
            switch self {
            case .weight: return e.weight
            case .fat: return e.fat
            case .muscle: return e.muscle
            }
        }
    }

    private var entries: [Inbody] {
        vm.byPlayer[playerId] ?? []
    }

    /// 값이 있는(>0) 측정만 검사일 오름차순 — 차트용.
    private var chartPoints: [(date: String, value: Double)] {
        entries
            .filter { metric.value(of: $0) > 0 }
            .sorted { $0.testdate < $1.testdate }
            .map { ($0.testdate, metric.value(of: $0)) }
    }

    var body: some View {
        ZStack {
            t.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Text("닫기").foregroundColor(t.textSec)
                    }
                    Spacer()
                    Text("\(vm.playerName(for: playerId)) · 인바디")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(t.text)
                    Spacer()
                    Button {
                        editing = InbodyDraft(playerId: playerId, testdate: Date.todayYMD)
                    } label: {
                        Image(systemName: "plus")
                            .font(.system(size: 15, weight: .bold))
                            .foregroundColor(t.accent)
                    }
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 14)

                ScrollView {
                    VStack(spacing: 14) {
                        if entries.isEmpty {
                            VStack(spacing: 10) {
                                Image(systemName: "figure.arms.open")
                                    .font(.system(size: 36))
                                    .foregroundColor(t.textTer)
                                Text("측정 기록이 없습니다")
                                    .font(.system(size: 14))
                                    .foregroundColor(t.textSec)
                            }
                            .padding(.top, 40)
                        } else {
                            latestSummary(entries[0])
                            chartCard
                            historyList
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 24)
                }
            }
        }
        .sheet(item: $editing) { draft in
            InbodyFormView(vm: vm, draft: draft)
                .environment(\.fsTheme, t)
        }
        .deleteConfirmation(
            "측정 기록 삭제",
            item: $deleting,
            message: { "\(vm.playerName(for: playerId)) 선수의 \($0.testdate) 측정 기록이 삭제됩니다." },
            onDelete: { entry in Task { _ = await vm.delete(id: entry.id) } }
        )
        // 시트가 열려 있을 땐 폼 쪽 alert가 처리하므로 닫힌 상태의 실패(삭제 등)만 노출
        .errorAlert($vm.errorMessage, enabled: editing == nil)
    }

    // MARK: - 최신 측정 요약

    private func latestSummary(_ latest: Inbody) -> some View {
        VStack(spacing: 8) {
            HStack {
                Text("최근 측정")
                    .font(.system(size: 11, weight: .bold))
                    .kerning(0.5)
                    .foregroundColor(t.textSec)
                Spacer()
                Text(latest.testdate)
                    .font(.system(size: 11, design: .rounded))
                    .foregroundColor(t.textTer)
            }
            HStack(spacing: 8) {
                FSStatTile(label: "신장", value: inbodyValue(latest.height, unit: "cm"))
                FSStatTile(label: "체중", value: inbodyValue(latest.weight, unit: "kg"))
                FSStatTile(label: "점수", value: inbodyValue(latest.score), accent: latest.score > 0)
            }
            HStack(spacing: 8) {
                FSStatTile(label: "골격근량", value: inbodyValue(latest.muscle, unit: "kg"))
                FSStatTile(label: "체지방률", value: inbodyValue(latest.fat, unit: "%"))
                FSStatTile(
                    label: "다리근육",
                    value: latest.rightleg > 0 || latest.leftleg > 0
                        ? "\(inbodyValue(latest.rightleg))/\(inbodyValue(latest.leftleg))"
                        : "-",
                    sub: "오른/왼(kg)"
                )
            }
        }
    }

    // MARK: - 추이 차트

    private var chartCard: some View {
        VStack(spacing: 12) {
            Picker("지표", selection: $metric) {
                ForEach(Metric.allCases) { m in
                    Text(m.rawValue).tag(m)
                }
            }
            .pickerStyle(.segmented)

            FSLineChart(points: chartPoints, unit: metric.unit)
        }
        .padding(14)
        .background(t.bgElev)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.line, lineWidth: 0.5))
    }

    // MARK: - 이력 리스트

    private var historyList: some View {
        VStack(spacing: 0) {
            ForEach(Array(entries.enumerated()), id: \.element.id) { i, entry in
                Button {
                    editing = .from(entry)
                } label: {
                    HStack(spacing: 10) {
                        Text(entry.testdate)
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(t.text)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("체중 \(inbodyValue(entry.weight, unit: "kg")) · 체지방 \(inbodyValue(entry.fat, unit: "%"))")
                                .font(.system(size: 12, design: .rounded))
                                .foregroundColor(t.text)
                            Text("골격근 \(inbodyValue(entry.muscle, unit: "kg")) · 점수 \(inbodyValue(entry.score))")
                                .font(.system(size: 10, design: .rounded))
                                .foregroundColor(t.textTer)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .contextMenu {
                    Button(role: .destructive) {
                        deleting = entry
                    } label: {
                        Label("측정 삭제", systemImage: "trash")
                    }
                }
                if i < entries.count - 1 {
                    Divider().background(t.line)
                }
            }
        }
        .fsCard()
    }
}
