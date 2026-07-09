import SwiftUI

struct MatchDetailView: View {
    let match: Match
    let team: Team
    @StateObject private var vm: QuarterViewModel
    @Environment(\.fsTheme) var t
    @Environment(\.dismiss) var dismiss
    @State private var showAddQuarter = false
    @State private var newQuarterDuration = 45
    @State private var showDeleteConfirm = false
    @State private var quarterToDelete: QuarterSummary?

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

    private var totalMinutes: Int {
        vm.summaries.reduce(0) { $0 + $1.quarter.duration }
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
                        FSGlassButton(action: { showDeleteConfirm = true }) {
                            Image(systemName: "trash")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundColor(t.neg)
                        }
                        .disabled(vm.isDeleting)
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
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
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
                                        .monospacedDigit()
                                        .foregroundColor(t.text)
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                    Text(":")
                                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                                        .foregroundColor(t.textTer)
                                        .padding(.bottom, 8)
                                    Text("\(totalAwayGoals)")
                                        .font(.system(size: 56, weight: .black, design: .rounded))
                                        .monospacedDigit()
                                        .foregroundColor(t.textSec)
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                }
                                Text(totalMinutes > 0 ? "총 \(totalMinutes)분" : "FT")
                                    .font(.system(size: 10, weight: .bold))
                                    .kerning(0.5)
                                    .monospacedDigit()
                                    .foregroundColor(t.textTer)
                            }
                        }

                        VStack(spacing: 8) {
                            FSCrest(name: match.awayname, size: 54, radius: 12)
                            Text(match.awayname)
                                .font(.system(size: 13, weight: .bold))
                                .multilineTextAlignment(.center)
                                .lineLimit(2)
                                .minimumScaleFactor(0.7)
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
                                Text("홈").frame(width: 56, alignment: .center)
                                Text("원정").frame(width: 76, alignment: .center)
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
                                .contextMenu {
                                    Button(role: .destructive) {
                                        quarterToDelete = summary
                                    } label: {
                                        Label("쿼터 삭제", systemImage: "trash")
                                    }
                                    .disabled(vm.deletingIds.contains(summary.id))
                                }
                            }
                        }
                        .fsCard()
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
                    Button {
                        // 기본 시간 프리필: 이전 쿼터 > 팀 설정값 > 45분
                        let lastDuration = vm.quarters.max(by: { $0.number < $1.number })?.duration
                        newQuarterDuration = lastDuration ?? team.duration ?? 45
                        showAddQuarter = true
                    } label: {
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
        .confirmationDialog(
            "경기 삭제",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("삭제", role: .destructive) {
                Task {
                    if await vm.deleteMatch() { dismiss() }
                }
            }
            Button("취소", role: .cancel) {}
        } message: {
            Text("'\(match.awayname)' 경기를 삭제하시겠습니까? 이 작업은 되돌릴 수 없습니다.")
        }
        .confirmationDialog(
            "쿼터 삭제",
            isPresented: Binding(
                get: { quarterToDelete != nil },
                set: { if !$0 { quarterToDelete = nil } }
            ),
            titleVisibility: .visible,
            presenting: quarterToDelete
        ) { summary in
            Button("삭제", role: .destructive) {
                Task { await vm.deleteQuarter(id: summary.quarter.id) }
            }
            Button("취소", role: .cancel) {}
        } message: { summary in
            Text("Q\(summary.quarter.number) 쿼터와 해당 쿼터의 선수 기록이 모두 삭제됩니다. 이 작업은 되돌릴 수 없습니다.")
        }
        .errorAlert($vm.errorMessage)
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
                .font(.system(size: 14, weight: .bold, design: .rounded))
                .monospacedDigit()
                .foregroundColor(t.text)
                .frame(width: 56, alignment: .center)
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
                    .monospacedDigit()
                    .foregroundColor(t.textSec)
                    .frame(minWidth: 22, alignment: .center)
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
            .frame(width: 76, alignment: .center)
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
