import SwiftUI

struct MatchDetailView: View {
    let match: Match
    let team: Team
    @StateObject private var vm: QuarterViewModel
    @Environment(\.fsTheme) var t
    @Environment(\.dismiss) var dismiss
    @State private var showAddQuarter = false
    @State private var newQuarterDuration = 45

    init(match: Match, team: Team) {
        self.match = match
        self.team = team
        _vm = StateObject(wrappedValue: QuarterViewModel(match: match))
    }

    private var dateString: String {
        guard let d = match.parsedDate else { return match.matchdate }
        let f = DateFormatter(); f.dateFormat = "yyyy.MM.dd · HH:mm"
        return f.string(from: d)
    }

    private var isFuture: Bool {
        (match.parsedDate ?? .distantPast) > Date()
    }

    private var totalHomeGoals: Int {
        vm.summaries.reduce(0) { $0 + $1.homeGoals }
    }

    private var totalAwayGoals: Int {
        vm.summaries.reduce(0) { $0 + $1.awayGoals }
    }

    var body: some View {
        ZStack(alignment: .bottom) {

            ScrollView {
                VStack(spacing: 0) {
                    // 네비
                    HStack {
                        FSGlassButton(action: { dismiss() }) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(t.text)
                        }
                        Spacer()
                        Text(isFuture ? "예정 경기" : "경기 결과")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(t.textSec)
                        Spacer()
                        Color.clear.frame(width: 36, height: 36)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 58)
                    .padding(.bottom, 8)

                    // 스코어라인
                    HStack(spacing: 0) {
                        VStack(spacing: 8) {
                            FSCrest(name: team.name, size: 54, radius: 12)
                            Text(team.name)
                                .font(.system(size: 13, weight: .bold))
                                .multilineTextAlignment(.center)
                                .foregroundColor(t.text)
                        }
                        .frame(maxWidth: .infinity)

                        VStack(spacing: 0) {
                            if isFuture {
                                Text("VS")
                                    .font(.system(size: 36, weight: .black, design: .rounded))
                                    .foregroundColor(t.textTer)
                                    .padding(.bottom, 6)
                                Text("예정")
                                    .font(.system(size: 10, weight: .bold))
                                    .kerning(0.5)
                                    .foregroundColor(t.accent)
                            } else {
                                HStack(alignment: .bottom, spacing: 14) {
                                    Text("\(totalHomeGoals)")
                                        .font(.system(size: 56, weight: .black, design: .rounded))
                                        .foregroundColor(t.text)
                                    Text(":")
                                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                                        .foregroundColor(t.textTer)
                                        .padding(.bottom, 8)
                                    Text("\(totalAwayGoals)")
                                        .font(.system(size: 56, weight: .black, design: .rounded))
                                        .foregroundColor(t.textSec)
                                }
                                Text("FT")
                                    .font(.system(size: 10, weight: .bold))
                                    .kerning(0.5)
                                    .foregroundColor(t.textTer)
                            }
                        }

                        VStack(spacing: 8) {
                            FSCrest(name: match.awayname, size: 54, radius: 12)
                            Text(match.awayname)
                                .font(.system(size: 13, weight: .bold))
                                .multilineTextAlignment(.center)
                                .foregroundColor(t.text)
                        }
                        .frame(maxWidth: .infinity)
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 12)

                    Text(dateString)
                        .font(.system(size: 11))
                        .foregroundColor(t.textSec)
                        .padding(.bottom, 16)

                    // 쿼터 점수 테이블
                    if vm.isLoading {
                        ProgressView().padding(.vertical, 24)
                    } else if !vm.summaries.isEmpty {
                        VStack(spacing: 0) {
                            HStack {
                                Text("쿼터").frame(maxWidth: .infinity, alignment: .leading)
                                Text("홈").frame(width: 52, alignment: .center)
                                Text("원정").frame(width: 52, alignment: .center)
                                Text("시간").frame(width: 60, alignment: .trailing)
                            }
                            .font(.system(size: 10, weight: .bold)).kerning(0.4).textCase(.uppercase)
                            .foregroundColor(t.textTer)
                            .padding(.horizontal, 14).padding(.vertical, 8)
                            .background(t.bgElev)
                            .overlay(Rectangle().fill(t.line).frame(height: 0.5), alignment: .bottom)

                            ForEach(vm.summaries) { summary in
                                NavigationLink(value: summary.quarter) {
                                    QuarterDetailRow(summary: summary) { newVal in
                                        Task { await vm.updateAwayGoals(quarterId: summary.quarter.id, awaygoals: newVal) }
                                    }
                                }
                                .buttonStyle(.plain)
                            }
                        }
                        .background(t.bgElev)
                        .cornerRadius(12)
                        .overlay(RoundedRectangle(cornerRadius: 12).stroke(t.line, lineWidth: 0.5))
                        .padding(.horizontal, 16)
                    } else if !isFuture {
                        Text("쿼터를 추가하고 기록을 입력하세요")
                            .font(.system(size: 13))
                            .foregroundColor(t.textSec)
                            .padding(.vertical, 24)
                    }
                }
                .padding(.bottom, 40)
            }
            .ignoresSafeArea(edges: .top)

            // FAB
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button { showAddQuarter = true } label: {
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
        .navigationDestination(for: Quarter.self) { quarter in
            RecordView(quarter: quarter, team: team, match: match)
                .environment(\.fsTheme, t)
        }
        .background(t.bg.ignoresSafeArea())
        .toolbar(.hidden, for: .navigationBar)
        .task { await vm.fetchQuarters() }
        .sheet(isPresented: $showAddQuarter) {
            AddQuarterSheet(
                quarterNumber: (vm.quarters.map(\.number).max() ?? 0) + 1,
                duration: $newQuarterDuration
            ) {
                Task { await vm.addNextQuarter(duration: newQuarterDuration) }
            }
            .environment(\.fsTheme, t)
        }
    }
}

// MARK: - AddQuarterSheet

struct AddQuarterSheet: View {
    let quarterNumber: Int
    @Binding var duration: Int
    let onConfirm: () -> Void
    @Environment(\.fsTheme) var t
    @Environment(\.dismiss) var dismiss

    private var quarterLabel: String {
        "Q\(quarterNumber)"
    }

    var body: some View {
        VStack(spacing: 0) {
            // 핸들
            Capsule()
                .fill(t.textTer)
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            Text(quarterLabel)
                .font(.system(size: 20, weight: .black))
                .foregroundColor(t.text)
                .padding(.bottom, 6)

            Text("경기 시간을 설정하세요")
                .font(.system(size: 13))
                .foregroundColor(t.textSec)
                .padding(.bottom, 32)

            // 시간 스테퍼
            HStack(spacing: 24) {
                Button {
                    duration = max(1, duration - 5)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(t.text)
                        .frame(width: 48, height: 48)
                        .background(t.bgElev)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(t.line, lineWidth: 0.5))
                }

                Text("\(duration)분")
                    .font(.system(size: 48, weight: .black, design: .rounded))
                    .foregroundColor(t.text)
                    .frame(minWidth: 120, alignment: .center)

                Button {
                    duration = min(120, duration + 5)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundColor(t.text)
                        .frame(width: 48, height: 48)
                        .background(t.bgElev)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(t.line, lineWidth: 0.5))
                }
            }
            .padding(.bottom, 40)

            Button {
                onConfirm()
                dismiss()
            } label: {
                Text("쿼터 추가")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(t.accent)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 24)

            Spacer()
        }
        .background(t.bg.ignoresSafeArea())
        .presentationDetents([.height(360)])
        .presentationDragIndicator(.hidden)
    }
}

// MARK: - QuarterDetailRow

struct QuarterDetailRow: View {
    let summary: QuarterSummary
    let onAwayGoalChange: (Int) -> Void
    @State private var awayGoals: Int
    @Environment(\.fsTheme) var t

    init(summary: QuarterSummary, onAwayGoalChange: @escaping (Int) -> Void) {
        self.summary = summary
        self.onAwayGoalChange = onAwayGoalChange
        _awayGoals = State(initialValue: summary.awayGoals)
    }

    private var label: String {
        "Q\(summary.quarter.number)"
    }

    var body: some View {
        HStack {
            Text(label)
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(t.text)
                .frame(maxWidth: .infinity, alignment: .leading)
            Text("\(summary.homeGoals)")
                .frame(width: 52, alignment: .center)
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .foregroundColor(t.text)
            // 원정 골 인라인 스테퍼
            HStack(spacing: 4) {
                Button {
                    awayGoals = max(0, awayGoals - 1)
                    onAwayGoalChange(awayGoals)
                } label: {
                    Image(systemName: "minus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(t.textSec)
                        .frame(width: 18, height: 18)
                        .background(t.bgElev3)
                        .clipShape(Circle())
                }
                Text("\(awayGoals)")
                    .font(.system(size: 14, weight: .bold, design: .rounded))
                    .foregroundColor(t.textSec)
                    .frame(minWidth: 16, alignment: .center)
                Button {
                    awayGoals = min(99, awayGoals + 1)
                    onAwayGoalChange(awayGoals)
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 9, weight: .bold))
                        .foregroundColor(t.textSec)
                        .frame(width: 18, height: 18)
                        .background(t.bgElev3)
                        .clipShape(Circle())
                }
            }
            .frame(width: 52, alignment: .center)
            Text("\(summary.quarter.duration)'")
                .frame(width: 60, alignment: .trailing)
                .font(.system(size: 12))
                .foregroundColor(t.textTer)
        }
        .font(.system(size: 14, design: .rounded))
        .frame(minHeight: 28)
        .padding(.horizontal, 14).padding(.vertical, 10)
        .contentShape(Rectangle())
        .overlay(Rectangle().fill(t.line).frame(height: 0.5), alignment: .top)
    }
}
