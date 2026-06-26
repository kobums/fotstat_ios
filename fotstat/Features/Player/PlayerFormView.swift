import SwiftUI

struct PlayerFormView: View {
    let title: String
    var initialName: String = ""
    var initialNumber: Int? = nil
    var initialPos: String? = nil
    var initialBirthdate: String? = nil
    let onSave: (String, Int?, String?, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.fsTheme) var t
    @State private var name: String
    @State private var numberText: String
    @State private var pos: String?
    @State private var birthDate: Date
    @State private var hasBirthdate: Bool

    private let positions = ["GK", "CB", "LB", "RB", "CDM", "CM", "CAM", "LW", "RW", "ST"]

    // "yyyy-MM-dd" <-> Date 변환용 (생년월일은 날짜만 사용)
    private static let birthdateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f
    }()

    init(title: String, initialName: String = "", initialNumber: Int? = nil,
         initialPos: String? = nil, initialBirthdate: String? = nil,
         onSave: @escaping (String, Int?, String?, String?) -> Void) {
        self.title = title
        self.initialName = initialName
        self.initialNumber = initialNumber
        self.initialPos = initialPos
        self.initialBirthdate = initialBirthdate
        self.onSave = onSave
        _name = State(initialValue: initialName)
        _numberText = State(initialValue: initialNumber.map { "\($0)" } ?? "")
        _pos = State(initialValue: initialPos)
        let parsed = initialBirthdate.flatMap { PlayerFormView.birthdateFormatter.date(from: $0) }
        _birthDate = State(initialValue: parsed ?? Calendar.current.date(from: DateComponents(year: 2000, month: 1, day: 1)) ?? Date())
        _hasBirthdate = State(initialValue: parsed != nil)
    }

    private var birthdateString: String? {
        hasBirthdate ? PlayerFormView.birthdateFormatter.string(from: birthDate) : nil
    }

    var body: some View {
        ZStack {
            t.bg.ignoresSafeArea()

            VStack(spacing: 0) {
                // 헤더
                HStack {
                    Button { dismiss() } label: {
                        Text("취소").foregroundColor(t.textSec)
                    }
                    Spacer()
                    Text(title)
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(t.text)
                    Spacer()
                    Button {
                        onSave(name, Int(numberText), pos, birthdateString)
                        dismiss()
                    } label: {
                        Text("저장")
                            .font(.system(size: 17, weight: .semibold))
                            .foregroundColor(name.isEmpty ? t.textSec : t.accent)
                    }
                    .disabled(name.isEmpty)
                }
                .padding(.horizontal, 24)
                .padding(.top, 20)
                .padding(.bottom, 32)

                VStack(spacing: 12) {
                    // 이름
                    TextField("선수 이름", text: $name)
                        .font(.system(size: 16))
                        .foregroundColor(t.text)
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(t.bgElev)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(t.line, lineWidth: 0.5))
                        .autocorrectionDisabled()
                        .textInputAutocapitalization(.never)

                    // 등번호
                    TextField("등번호 (선택)", text: $numberText)
                        .font(.system(size: 16))
                        .foregroundColor(t.text)
                        .padding(.horizontal, 16)
                        .frame(height: 52)
                        .background(t.bgElev)
                        .cornerRadius(10)
                        .overlay(RoundedRectangle(cornerRadius: 10).stroke(t.line, lineWidth: 0.5))
                        .keyboardType(.numberPad)

                    // 포지션
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(positions, id: \.self) { p in
                                Button { pos = (pos == p ? nil : p) } label: {
                                    Text(p)
                                        .font(.system(size: 12, weight: .semibold))
                                        .foregroundColor(pos == p ? .white : t.textSec)
                                        .padding(.horizontal, 12).padding(.vertical, 7)
                                        .background(pos == p ? t.accent : t.bgElev)
                                        .cornerRadius(8)
                                        .overlay(RoundedRectangle(cornerRadius: 8).stroke(t.line, lineWidth: 0.5))
                                }
                            }
                        }
                    }

                    // 생년월일 (선택)
                    HStack {
                        Text("생년월일")
                            .font(.system(size: 16))
                            .foregroundColor(t.text)
                        Spacer()
                        if hasBirthdate {
                            DatePicker("", selection: $birthDate, in: ...Date(), displayedComponents: .date)
                                .labelsHidden()
                                .environment(\.locale, Locale(identifier: "ko_KR"))
                            Button { hasBirthdate = false } label: {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(t.textTer)
                            }
                        } else {
                            Button { hasBirthdate = true } label: {
                                Text("추가")
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundColor(t.accent)
                            }
                        }
                    }
                    .padding(.horizontal, 16)
                    .frame(height: 52)
                    .background(t.bgElev)
                    .cornerRadius(10)
                    .overlay(RoundedRectangle(cornerRadius: 10).stroke(t.line, lineWidth: 0.5))
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
    }
}
