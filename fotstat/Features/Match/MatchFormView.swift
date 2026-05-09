import SwiftUI

struct MatchFormView: View {
    let onSave: (String, Date) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.fsTheme) var t
    @State private var awayName = ""
    @State private var matchDate = Date()

    var body: some View {
        ZStack {
            t.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Text("취소").foregroundColor(t.textSec)
                    }
                    Spacer()
                    Text("경기 추가")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(t.text)
                    Spacer()
                    Button {
                        onSave(awayName, matchDate)
                        dismiss()
                    } label: {
                        Text("저장")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(awayName.isEmpty ? t.textSec : t.accent)
                    }
                    .disabled(awayName.isEmpty)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 32)

                VStack(spacing: 12) {
                    TextField("상대팀 이름", text: $awayName)
                        .font(.system(size: 16))
                        .foregroundColor(t.text)
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(t.bgElev)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(t.line, lineWidth: 0.5))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    DatePicker("경기 일시", selection: $matchDate, displayedComponents: [.date, .hourAndMinute])
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(t.bgElev)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(t.line, lineWidth: 0.5))
                        .foregroundColor(t.text)
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
    }
}
