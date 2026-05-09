import SwiftUI

// Legacy component – kept for backward compatibility
// New code should use FSTheme inline styling
struct FotTextField: View {
    let placeholder: String
    @Binding var text: String
    var isSecure: Bool = false
    @Environment(\.fsTheme) var t

    var body: some View {
        Group {
            if isSecure {
                SecureField(placeholder, text: $text)
            } else {
                TextField(placeholder, text: $text)
            }
        }
        .font(.system(size: 16))
        .foregroundColor(t.text)
        .padding(.horizontal, 16)
        .frame(height: 52)
        .background(t.bgElev)
        .cornerRadius(10)
        .overlay(RoundedRectangle(cornerRadius: 10).stroke(t.line, lineWidth: 0.5))
        .autocorrectionDisabled()
        .textInputAutocapitalization(.never)
    }
}
