import SwiftUI

struct PlayerFormView: View {
    let title: String
    var initialName: String = ""
    var initialNumber: Int? = nil
    var initialPos: String? = nil
    let onSave: (String, Int?, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.fsTheme) var t
    @State private var name: String
    @State private var numberText: String
    @State private var pos: String?

    private let positions = ["GK", "CB", "LB", "RB", "CDM", "CM", "CAM", "LW", "RW", "ST"]

    init(title: String, initialName: String = "", initialNumber: Int? = nil,
         initialPos: String? = nil, onSave: @escaping (String, Int?, String?) -> Void) {
        self.title = title
        self.initialName = initialName
        self.initialNumber = initialNumber
        self.initialPos = initialPos
        self.onSave = onSave
        _name = State(initialValue: initialName)
        _numberText = State(initialValue: initialNumber.map { "\($0)" } ?? "")
        _pos = State(initialValue: initialPos)
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
                        onSave(name, Int(numberText), pos)
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
                }
                .padding(.horizontal, 24)

                Spacer()
            }
        }
    }
}
