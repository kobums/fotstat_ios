import SwiftUI

/// 훈련 탭 루트 — 세션 목록·참석 체크·선수별 참석 집계를 한곳에서 다룬다.
/// 행 탭 = 참석 체크, "수정" = 일시 수정/삭제, FAB = 신규 등록.
struct TrainingListView: View {
    @StateObject private var vm: TrainingViewModel
    @State private var editing: TrainingDraft? = nil
    @State private var checking: Training? = nil
    @Environment(\.fsTheme) var t

    init(team: Team) {
        _vm = StateObject(wrappedValue: TrainingViewModel(team: team))
    }

    var body: some View {
        ZStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    FSTeamHeader(team: vm.team, tab: .stats)

                    if vm.isLoading && vm.trainings.isEmpty {
                        ProgressView().padding(.top, 80)
                    } else if vm.trainings.isEmpty {
                        VStack(spacing: 12) {
                            Image(systemName: "figure.run").font(.system(size: 40)).foregroundColor(t.textTer)
                            Text("훈련 기록이 없습니다").font(.system(size: 15)).foregroundColor(t.textSec)
                            Text("훈련을 등록하고 참석과 훈련 시간을 기록하세요")
                                .font(.system(size: 12)).foregroundColor(t.textTer)
                        }
                        .frame(maxWidth: .infinity).padding(.top, 40)
                    } else {
                        trainingList

                        if hasHeldTraining {
                            playerStatsSection
                        }
                    }
                }
                .padding(.bottom, 100)
            }

            // FAB
            FSFloatingActionButton { editing = .new() }
        }
        .background(t.bg.ignoresSafeArea())
        .task { await vm.fetch() }
        .onReceive(NotificationCenter.default.publisher(for: .injuryChanged)) { _ in
            // 부상 등록·복귀가 바뀌면 참석 체크의 비활성 대상도 갱신
            Task { await vm.fetch() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .playerDeleted)) { _ in
            Task { await vm.fetch() }
        }
        .sheet(item: $editing) { draft in
            TrainingFormView(vm: vm, draft: draft)
                .environment(\.fsTheme, t)
        }
        .sheet(item: $checking) { training in
            AttendanceFormView(vm: vm, training: training)
                .environment(\.fsTheme, t)
        }
        // 시트가 열려 있을 땐 시트 쪽 alert가 처리하므로 닫힌 상태의 실패(조회)만 노출
        .errorAlert($vm.errorMessage, enabled: editing == nil && checking == nil)
    }

    /// 오늘까지 열린 훈련이 하나라도 있어야 집계 섹션을 보여준다.
    private var hasHeldTraining: Bool {
        let today = Date.todayYMD
        return vm.trainings.contains { $0.trainingdate.dayPrefix <= today }
    }

    // MARK: - 훈련 일정

    private var trainingList: some View {
        VStack(spacing: 0) {
            FSSectionHeader(title: "훈련 일정")
            VStack(spacing: 0) {
                ForEach(Array(vm.sortedTrainings.enumerated()), id: \.element.id) { i, training in
                    HStack(spacing: 0) {
                        Button {
                            checking = training
                        } label: {
                            TrainingRow(
                                training: training,
                                attendedCount: vm.attendances(for: training.id).count,
                                playerCount: vm.players.count
                            )
                        }
                        .buttonStyle(.plain)

                        Button {
                            editing = .from(training)
                        } label: {
                            Text("수정")
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
                    if i < vm.sortedTrainings.count - 1 {
                        Divider().background(t.line)
                    }
                }
            }
            .fsCard()
            .padding(.horizontal, 16)
        }
    }

    // MARK: - 선수별 참석

    private var playerStatsSection: some View {
        VStack(spacing: 0) {
            FSSectionHeader(title: "선수별 참석")
            VStack(spacing: 0) {
                let rows = vm.players
                    .map { (player: $0, stats: vm.stats(for: $0.id)) }
                    .sorted {
                        $0.stats.attended != $1.stats.attended
                            ? $0.stats.attended > $1.stats.attended
                            : $0.player.name < $1.player.name
                    }
                ForEach(Array(rows.enumerated()), id: \.element.player.id) { i, row in
                    HStack(spacing: 10) {
                        FSPlayerAvatar(number: row.player.number, size: 30)
                        Text(row.player.name)
                            .font(.system(size: 14, weight: .semibold))
                            .foregroundColor(t.text)
                            .lineLimit(1)
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(row.stats.attended)/\(row.stats.held)회 (\(row.stats.rate)%)")
                                .font(.system(size: 12, weight: .bold, design: .rounded))
                                .foregroundColor(t.text)
                            Text("총 \(row.stats.totalMin)분")
                                .font(.system(size: 10))
                                .foregroundColor(t.textTer)
                        }
                    }
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    if i < rows.count - 1 {
                        Divider().background(t.line)
                    }
                }
            }
            .fsCard()
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - TrainingRow

private struct TrainingRow: View {
    let training: Training
    let attendedCount: Int
    let playerCount: Int
    @Environment(\.fsTheme) var t

    private var dateString: String {
        guard let d = training.parsedDate else { return training.trainingdate }
        let f = DateFormatter()
        f.dateFormat = "M월 d일 (E) · HH:mm"
        f.locale = Locale(identifier: "ko_KR")
        return f.string(from: d)
    }

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "figure.run")
                .font(.system(size: 15, weight: .semibold))
                .foregroundColor(t.textSec)
                .frame(width: 34, height: 34)
                .background(t.bgElev3)
                .clipShape(Circle())

            HStack(spacing: 6) {
                Text(dateString)
                    .font(.system(size: 14, weight: .bold))
                    .foregroundColor(t.text)
                if training.isUpcoming {
                    Text("예정")
                        .font(.system(size: 10, weight: .black))
                        .foregroundColor(t.textSec)
                        .padding(.horizontal, 5).padding(.vertical, 2)
                        .background(t.bgElev3)
                        .cornerRadius(4)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Text("참석 \(attendedCount)/\(playerCount)명")
                .font(.system(size: 12, weight: .bold, design: .rounded))
                .foregroundColor(t.text)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
        .contentShape(Rectangle())
    }
}
