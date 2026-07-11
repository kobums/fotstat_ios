import SwiftUI
import Combine

// MARK: - MatchReportItem (경기별 쿼터 리포트 — 웹 buildMatchReports 미러)

struct MatchReportItem: Identifiable {
    struct QuarterLine: Identifiable {
        let id: Int
        let number: Int
        let home: Int
        let away: Int
        let duration: Int
    }

    let match: Match
    let home: Int
    let away: Int
    let quarters: [QuarterLine]
    var id: Int { match.id }

    var result: String { home > away ? "W" : (home < away ? "L" : "D") }
    var resultLabel: String { home > away ? "승" : (home < away ? "패" : "무") }
}

// MARK: - ReportViewModel

@MainActor
final class ReportViewModel: ObservableObject {
    @Published var stats: TeamStats?
    @Published var reports: [MatchReportItem] = []
    /// 현재 기간 원본 — 선수 상세의 경기별 기록·부상 섹션용.
    @Published var raw: TeamStatsRaw?
    @Published var isLoading = false
    @Published var isExporting = false
    @Published var exportError: String?

    let team: Team

    init(team: Team) {
        self.team = team
    }

    /// 조회 기간의 경기기록표 xlsx 를 백엔드에서 받아 임시 파일로 저장하고 그 URL 을 돌려준다.
    /// 실패 시 exportError 를 세팅하고 nil.
    func exportMatchRecord(start: Date?, end: Date?) async -> URL? {
        isExporting = true
        defer { isExporting = false }
        let startStr = start.map { DateFormats.day.string(from: $0) }
        let endStr = end.map { DateFormats.day.string(from: $0) }
        do {
            let (data, filename) = try await APIClient.shared.download(
                .matchRecordReport(teamId: team.id, start: startStr, end: endStr)
            )
            let url = FileManager.default.temporaryDirectory.appendingPathComponent(filename)
            try data.write(to: url, options: .atomic)
            return url
        } catch {
            exportError = (error as? LocalizedError)?.errorDescription ?? "다운로드에 실패했습니다."
            return nil
        }
    }

    func fetch(start startDate: Date?, end endDate: Date?) async {
        isLoading = true
        defer { isLoading = false }
        let start = startDate.map { Calendar.current.startOfDay(for: $0) }
        guard let loaded = await loadStatsRaw(teamId: team.id, from: start, to: endDate) else {
            raw = nil
            stats = nil
            reports = []
            return
        }
        // 한 번의 fan-out 결과로 요약·순위(computeTeamStats)와 경기별 카드 모두 생성
        raw = loaded
        stats = computeTeamStats(loaded)
        reports = Self.buildReports(loaded)
    }

    /// 경기별 쿼터 결과. 홈 득점 = 쿼터별 record.goal 합, 원정 득점 = quarter.awaygoals.
    /// 쿼터가 없는(미진행) 경기는 제외하고 최신순 정렬 — 웹 buildMatchReports와 동일 규칙.
    static func buildReports(_ raw: TeamStatsRaw) -> [MatchReportItem] {
        var goalsByQuarter: [Int: Int] = [:]
        for r in raw.records { goalsByQuarter[r.quarter, default: 0] += r.goal }

        var linesByMatch: [Int: [MatchReportItem.QuarterLine]] = [:]
        for q in raw.quarters {
            let line = MatchReportItem.QuarterLine(
                id: q.id, number: q.number,
                home: goalsByQuarter[q.id] ?? 0, away: q.awaygoals,
                duration: q.duration
            )
            linesByMatch[q.match, default: []].append(line)
        }

        return raw.finished
            .filter { linesByMatch[$0.id] != nil }
            .sorted { ($0.parsedDate ?? .distantPast) > ($1.parsedDate ?? .distantPast) }
            .map { match in
                let lines = (linesByMatch[match.id] ?? []).sorted { $0.number < $1.number }
                return MatchReportItem(
                    match: match,
                    home: lines.reduce(0) { $0 + $1.home },
                    away: lines.reduce(0) { $0 + $1.away },
                    quarters: lines
                )
            }
    }
}

// MARK: - ReportView (리포트 탭)

struct ReportView: View {
    let team: Team
    /// 통계 탭과 공유하는 조회 기간 (TeamContextView 소유)
    @ObservedObject var period: StatsPeriod
    @StateObject private var vm: ReportViewModel
    @Environment(\.fsTheme) var t
    // iPad(세로 포함)는 순위를 좌우 배치 + 전체 펼침, iPhone은 세로 스택 + top3.
    @Environment(\.horizontalSizeClass) private var hSize
    /// 본문|순위 2단으로 나누는 최소 폭. iPad 가로(1133~1366pt)만 해당하고
    /// iPad 세로(744~1024pt)·iPhone은 세로 스택 — 사이즈 클래스는 iPad
    /// 세로에서도 regular라 방향 구분이 안 되므로 실제 폭으로 판단한다.
    private static let wideLayoutMinWidth: CGFloat = 1100

    /// 공유 시트에 넘길 다운로드 파일 URL (nil 이면 시트 닫힘).
    @State private var shareURL: ShareURL?

    /// 통계 탭에서 시트로 열릴 때의 닫기 액션 — 헤더 왼쪽 back 버튼으로 노출된다.
    private let onClose: (() -> Void)?

    init(team: Team, period: StatsPeriod, onClose: (() -> Void)? = nil) {
        self.team = team
        self.period = period
        self.onClose = onClose
        _vm = StateObject(wrappedValue: ReportViewModel(team: team))
    }

    var body: some View {
        GeometryReader { geo in
            reportBody(isWide: geo.size.width >= Self.wideLayoutMinWidth)
        }
    }

    private func reportBody(isWide: Bool) -> some View {
        ScrollView {
            VStack(spacing: 0) {
                FSTeamHeader(team: team, tab: .stats, onBack: onClose)

                // 재조회는 아래 onChange(period.key) 한 곳에서 처리 (초기화처럼
                // 두 날짜가 함께 바뀌어도 한 번만 fan-out)
                // 날짜 선택 row 오른쪽 끝에 다운로드 버튼. DateRangeFilter가
                // maxWidth:.infinity로 가운데 정렬이라 버튼은 자연히 우측 끝에 놓인다.
                HStack(spacing: 8) {
                    DateRangeFilter(startDate: $period.startDate, endDate: $period.endDate) {}
                    exportButton
                }
                .padding(.horizontal, 16)
                .padding(.top, 14)

                if vm.isLoading {
                    ProgressView().padding(.top, 40)
                } else if (vm.stats?.matchCount ?? 0) == 0 {
                    VStack(spacing: 10) {
                        Image(systemName: "doc.text")
                            .font(.system(size: 40))
                            .foregroundColor(t.textTer)
                        Text("집계할 경기가 없습니다")
                            .font(.system(size: 15, weight: .semibold))
                            .foregroundColor(t.textSec)
                        Text("다른 기간을 선택하거나 쿼터와 기록을 추가해보세요")
                            .font(.system(size: 12))
                            .foregroundColor(t.textTer)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 60)
                } else {
                    // iPad 가로: 웹 리포트와 동일한 2단 —
                    // 왼쪽 [요약 타일 + 경기 결과] | 오른쪽 [득점 순위 | 출전 시간 순위(좌우)]
                    if isWide {
                        HStack(alignment: .top, spacing: 0) {
                            VStack(spacing: 0) {
                                summaryTiles
                                    .padding(.top, 10)
                                matchesSection
                            }
                            .frame(maxWidth: .infinity, alignment: .top)

                            rankingsSideBySide
                                .frame(width: 720)
                                .padding(.top, 10)
                        }
                    } else {
                        summaryTiles
                            .padding(.top, 10)
                        matchesSection
                        // iPad 세로: 순위 좌우 배치 + 전체 펼침. iPhone: 세로 스택 + top3.
                        if hSize == .regular {
                            rankingsSideBySide
                        } else {
                            rankingsSection
                        }
                    }
                }
            }
            .padding(.bottom, 10)
        }
        .background(t.bg.ignoresSafeArea())
        .sheet(item: $shareURL) { item in
            ActivityView(items: [item.url])
        }
        .alert("다운로드 실패", isPresented: Binding(
            get: { vm.exportError != nil },
            set: { if !$0 { vm.exportError = nil } }
        )) {
            Button("확인", role: .cancel) { vm.exportError = nil }
        } message: {
            Text(vm.exportError ?? "")
        }
        .task { await refetch() }
        // 통계 탭에서 기간을 바꿔도 이 탭이 함께 갱신된다 (공유 StatsPeriod)
        .onChange(of: period.key) { _, _ in
            Task { await refetch() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .matchDeleted)) { _ in
            Task { await refetch() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .playerDeleted)) { _ in
            Task { await refetch() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .injuryChanged)) { _ in
            Task { await refetch() }
        }
    }

    private func refetch() async {
        await vm.fetch(start: period.startDate, end: period.endDate)
    }

    // 날짜 row 우측 끝 컴팩트 아이콘 버튼. 경기기록표 xlsx 다운로드 →
    // 시스템 공유 시트(파일 저장·공유). 집계 경기가 없으면 비활성.
    private var exportButton: some View {
        let hasData = (vm.stats?.matchCount ?? 0) > 0
        return Button {
            Task {
                if let url = await vm.exportMatchRecord(start: period.startDate, end: period.endDate) {
                    shareURL = ShareURL(url: url)
                }
            }
        } label: {
            Group {
                if vm.isExporting {
                    ProgressView().controlSize(.small)
                } else {
                    Image(systemName: "square.and.arrow.down")
                        .font(.system(size: 12, weight: .bold))
                }
            }
            .foregroundColor(hasData ? t.text : t.textTer)
            .frame(width: 30, height: 30)
            .background(t.bgElev3)
            .clipShape(Circle())
            .overlay(Circle().stroke(t.line, lineWidth: 0.5))
        }
        .buttonStyle(.plain)
        .disabled(!hasData || vm.isExporting)
        .accessibilityLabel("경기기록표 다운로드")
    }

    // 웹 리포트 상단과 동일: 골(n경기) · 도움 · 승률(W D L)
    private var summaryTiles: some View {
        let stats = vm.stats
        let mc = stats?.matchCount ?? 0
        let winRate = mc > 0 ? Int(Double(stats?.wins ?? 0) / Double(mc) * 100) : 0
        return HStack(spacing: 8) {
            FSStatTile(label: "골", value: "\(stats?.totalGoal ?? 0)", sub: "\(mc)경기", accent: true)
            FSStatTile(label: "도움", value: "\(stats?.totalAssist ?? 0)", sub: "어시스트")
            FSStatTile(label: "승률", value: "\(winRate)%",
                       sub: "W\(stats?.wins ?? 0) D\(stats?.draws ?? 0) L\(stats?.losses ?? 0)")
        }
        .padding(.horizontal, 16)
    }

    private var matchesSection: some View {
        VStack(spacing: 0) {
            FSSectionHeader(title: "경기 결과")
            // iPad는 넓으니 카드 2열, iPhone은 1열
            let columns = [GridItem(.adaptive(minimum: 260), spacing: 12)]
            LazyVGrid(columns: columns, spacing: 12) {
                ForEach(vm.reports) { report in
                    NavigationLink(value: report.match) {
                        MatchReportCard(team: team, report: report)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }

    // 세로 모드: 득점/출전 순위를 위아래로 (top3 + 자세히 보기)
    private var rankingsSection: some View {
        VStack(spacing: 0) {
            goalRanking(expanded: false)
            minRanking(expanded: false)
        }
    }

    // iPad 가로: 득점 | 출전 순위를 좌우로, 전체 순위를 펼쳐서 (자세히 보기 없음 —
    // 웹 리포트 오른쪽 컬럼과 동일). 컬럼 폭 720(반쪽 360)이면 이름(4자)+
    // 풀 서브라벨(5경기 · 0G 0A)이 함께 들어간다.
    private var rankingsSideBySide: some View {
        HStack(alignment: .top, spacing: 0) {
            VStack(spacing: 0) { goalRanking(expanded: true) }
                .frame(maxWidth: .infinity, alignment: .top)
            VStack(spacing: 0) { minRanking(expanded: true) }
                .frame(maxWidth: .infinity, alignment: .top)
        }
    }

    @ViewBuilder
    private func goalRanking(expanded: Bool) -> some View {
        if let stats = vm.stats, !stats.players.isEmpty {
            RankingSection(title: "득점 순위", players: stats.players,
                value: { $0.goal },
                valueLabel: { "\($0.goal)G" },
                subLabel: { "+\($0.assist)A" },
                expanded: expanded,
                raw: vm.raw)
        }
    }

    @ViewBuilder
    private func minRanking(expanded: Bool) -> some View {
        if let stats = vm.stats, !stats.players.isEmpty {
            RankingSection(title: "출전 시간 순위", players: stats.players,
                value: { $0.min },
                valueLabel: { "\($0.min)'" },
                subLabel: { "\($0.games)경기 · \($0.goal)G \($0.assist)A" },
                expanded: expanded,
                raw: vm.raw)
        }
    }
}

// MARK: - MatchReportCard (경기별 쿼터 스코어 카드)

private struct MatchReportCard: View {
    let team: Team
    let report: MatchReportItem
    @Environment(\.fsTheme) var t

    // 카드가 리스트로 렌더링되므로 포매터는 static 캐시 (기존 컨벤션)
    private static let dateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "M월 d일 (E) a h:mm"
        f.locale = Locale(identifier: "ko_KR")
        return f
    }()

    private var dateString: String {
        guard let d = report.match.parsedDate else { return report.match.matchdate }
        return Self.dateFormatter.string(from: d)
    }

    var body: some View {
        VStack(spacing: 10) {
            // 스코어보드: 홈 | 점수·결과 | 원정
            HStack(alignment: .top, spacing: 8) {
                sideView(name: team.name)
                VStack(spacing: 6) {
                    HStack(spacing: 4) {
                        Text("\(report.home)")
                        Text(":").foregroundColor(t.textTer)
                        Text("\(report.away)")
                    }
                    .font(.system(size: 26, weight: .black, design: .rounded))
                    .monospacedDigit()
                    .foregroundColor(t.text)
                    FSResultPill(result: report.result, label: report.resultLabel, size: 20)
                }
                .padding(.top, 2)
                sideView(name: report.match.awayname)
            }

            Text(dateString)
                .font(.system(size: 11))
                .foregroundColor(t.textSec)

            // 쿼터 테이블: 쿼터 / 홈 / 원정 / 시간
            VStack(spacing: 0) {
                HStack {
                    Text("쿼터").frame(width: 40, alignment: .leading)
                    Text("홈").frame(maxWidth: .infinity)
                    Text("원정").frame(maxWidth: .infinity)
                    Text("시간").frame(width: 40, alignment: .trailing)
                }
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(t.textTer)
                .padding(.vertical, 6)
                Divider().background(t.line)

                ForEach(Array(report.quarters.enumerated()), id: \.element.id) { i, q in
                    HStack {
                        Text("Q\(q.number)")
                            .font(.system(size: 12, weight: .bold))
                            .foregroundColor(t.textSec)
                            .frame(width: 40, alignment: .leading)
                        Text("\(q.home)")
                            .font(.system(size: 13, weight: .semibold))
                            .monospacedDigit()
                            .foregroundColor(t.text)
                            .frame(maxWidth: .infinity)
                        Text("\(q.away)")
                            .font(.system(size: 13, weight: .semibold))
                            .monospacedDigit()
                            .foregroundColor(t.text)
                            .frame(maxWidth: .infinity)
                        Text("\(q.duration)′")
                            .font(.system(size: 12))
                            .monospacedDigit()
                            .foregroundColor(t.textTer)
                            .frame(width: 40, alignment: .trailing)
                    }
                    .padding(.vertical, 7)
                    if i < report.quarters.count - 1 {
                        Divider().background(t.line)
                    }
                }
            }
        }
        .padding(14)
        .background(t.bgElev)
        .cornerRadius(14)
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(t.line, lineWidth: 0.5))
    }

    private func sideView(name: String) -> some View {
        VStack(spacing: 6) {
            FSCrest(name: name, size: 36, radius: 8)
            Text(name)
                .font(.system(size: 11, weight: .semibold))
                .foregroundColor(t.textSec)
                .lineLimit(1)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - 공유 시트 (UIActivityViewController)

/// .sheet(item:) 에 쓰기 위한 Identifiable 래퍼.
private struct ShareURL: Identifiable {
    let url: URL
    var id: String { url.absoluteString }
}

/// 시스템 공유 시트로 파일(xlsx)을 저장·공유한다.
private struct ActivityView: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ controller: UIActivityViewController, context: Context) {}
}
