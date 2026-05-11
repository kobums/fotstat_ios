import SwiftUI

struct DateRangeFilter: View {
    @Binding var startDate: Date?
    @Binding var endDate: Date?
    let onApply: () -> Void

    @Environment(\.fsTheme) var t
    @State private var showingStart = false
    @State private var showingEnd = false

    private let fmt: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yy.MM.dd"
        return f
    }()

    private var defaultStart: Date? { Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date())) }
    private var defaultEnd: Date { Date() }

    var isFiltered: Bool {
        if let s = startDate, let d = defaultStart, !Calendar.current.isDate(s, inSameDayAs: d) { return true }
        if let e = endDate, !Calendar.current.isDate(e, inSameDayAs: defaultEnd) { return true }
        return false
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
                    startDate = Calendar.current.date(from: Calendar.current.dateComponents([.year, .month], from: Date()))
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

            Spacer()
        }
        .background(t.bg.ignoresSafeArea())
        .presentationDetents([.height(480)])
        .presentationDragIndicator(.hidden)
    }
}
