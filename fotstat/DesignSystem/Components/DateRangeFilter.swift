import SwiftUI

struct DateRangeFilter: View {
    @Binding var startDate: Date?
    @Binding var endDate: Date?
    let onApply: () -> Void
    /// 초기화 버튼이 되돌리는 기본 시작일. 통계 탭은 이번 달 1일, 선수 상세는 올해 1월 1일.
    var defaultStart: Date? = DateRangeFilter.monthStart

    @Environment(\.fsTheme) var t
    @State private var showingStart = false
    @State private var showingEnd = false

    private let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yy.MM.dd"
        return f
    }()

    static var monthStart: Date? { Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) }
    static var yearStart: Date? { Calendar.current.date(from: Calendar.current.dateComponents([.year], from: Date())) }
    private var defaultEnd: Date { Date() }

    /// 기본 기간과 다르면 필터 중 — 한쪽이 nil(열린 구간)인 것도 기본과 다르므로 필터로 본다.
    var isFiltered: Bool {
        !Self.sameDay(startDate, defaultStart) || !Self.sameDay(endDate, defaultEnd)
    }

    private static func sameDay(_ a: Date?, _ b: Date?) -> Bool {
        switch (a, b) {
        case (nil, nil): return true
        case let (x?, y?): return Calendar.current.isDate(x, inSameDayAs: y)
        default: return false
        }
    }

    var body: some View {
        HStack(spacing: 8) {
            DateChip(
                label: startDate.map { fmt.string(from: $0) } ?? "시작일",
                isSet: startDate != nil,
                onTap: { showingStart = true }
            )

            Image(systemName: "arrow.right")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(t.textTer)

            DateChip(
                label: endDate.map { fmt.string(from: $0) } ?? "종료일",
                isSet: endDate != nil,
                onTap: { showingEnd = true }
            )

            if isFiltered {
                Button {
                    startDate = defaultStart
                    endDate = Date()
                    onApply()
                } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundColor(t.textSec)
                        .frame(width: 26, height: 26)
                        .background(t.bgElev3)
                        .clipShape(Circle())
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .sheet(isPresented: $showingStart) {
            DatePickerSheet(title: "시작일", date: startDate ?? Date()) { picked in
                startDate = picked
                if let e = endDate, picked > e { endDate = nil }
                onApply()
            }
        }
        .sheet(isPresented: $showingEnd) {
            DatePickerSheet(title: "종료일", date: endDate ?? Date()) { picked in
                endDate = picked
                if let s = startDate, picked < s { startDate = nil }
                onApply()
            }
        }
    }
}

private struct DateChip: View {
    let label: String
    let isSet: Bool
    let onTap: () -> Void
    @Environment(\.fsTheme) var t

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 4) {
                Image(systemName: "calendar")
                    .font(.system(size: 10, weight: .semibold))
                Text(label)
                    .font(.system(size: 12, weight: .semibold))
            }
            .foregroundColor(isSet ? .white : t.textSec)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(isSet ? t.accent : t.bgElev)
            .cornerRadius(20)
            .overlay(RoundedRectangle(cornerRadius: 20).stroke(isSet ? Color.clear : t.line, lineWidth: 0.5))
        }
    }
}

private struct DatePickerSheet: View {
    let title: String
    let date: Date
    let onConfirm: (Date) -> Void

    @Environment(\.fsTheme) var t
    @Environment(\.dismiss) var dismiss
    @State private var selected: Date

    init(title: String, date: Date, onConfirm: @escaping (Date) -> Void) {
        self.title = title
        self.date = date
        self.onConfirm = onConfirm
        _selected = State(initialValue: date)
    }

    var body: some View {
        VStack(spacing: 0) {
            Capsule()
                .fill(t.textTer)
                .frame(width: 36, height: 4)
                .padding(.top, 12)
                .padding(.bottom, 20)

            Text(title)
                .font(.system(size: 17, weight: .bold))
                .foregroundColor(t.text)
                .padding(.bottom, 16)

            DatePicker("", selection: $selected, displayedComponents: .date)
                .datePickerStyle(.graphical)
                .tint(t.accent)
                // graphical 스타일은 가용 폭에 비례해 커지므로 iPad 시트에서
                // 캘린더가 거대해져 선택 버튼을 밀어내지 않게 폭을 제한한다
                .frame(maxWidth: 420)
                .padding(.horizontal, 16)

            Button {
                onConfirm(selected)
                dismiss()
            } label: {
                Text("선택")
                    .font(.system(size: 16, weight: .bold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .frame(height: 52)
                    .background(t.accent)
                    .cornerRadius(14)
            }
            .padding(.horizontal, 24)
            .padding(.top, 8)
            .padding(.bottom, 20)
        }
        .background(t.bg.ignoresSafeArea())
        // iPhone: 480pt 바텀시트. iPad: 중앙 form 시트(폭 540) + 높이 660 —
        // detents 높이가 form 시트에도 적용되므로 캘린더+버튼이 다 들어가게 키운다.
        // (fitted는 graphical DatePicker의 ideal 폭을 좁게 계산해 시트가 세로
        //  막대처럼 붕괴하므로 쓰지 않는다. form 시트 내부는 size class가 compact라
        //  기기 idiom으로 분기한다.)
        .presentationDetents([.height(Self.isPad ? 660 : 480)])
        .presentationSizing(.form)
        .presentationDragIndicator(.hidden)
    }

    private static let isPad = UIDevice.current.userInterfaceIdiom == .pad
}
