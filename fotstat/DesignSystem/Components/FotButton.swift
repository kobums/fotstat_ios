import SwiftUI

struct FotButton: View {
    let title: String
    let action: () -> Void
    var style: Style = .primary
    var isLoading: Bool = false

    enum Style {
        case primary, secondary
    }

    var body: some View {
        Button(action: action) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(style == .primary ? Color.theme.primaryAdaptive : Color.clear)
                    .overlay(
                        RoundedRectangle(cornerRadius: 10)
                            .stroke(Color.theme.primaryAdaptive, lineWidth: style == .secondary ? 1 : 0)
                    )

                if isLoading {
                    ProgressView()
                        .tint(style == .primary ? Color.theme.backgroundAdaptive : Color.theme.primaryAdaptive)
                } else {
                    Text(title)
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(style == .primary ? Color.theme.backgroundAdaptive : Color.theme.primaryAdaptive)
                }
            }
            .frame(height: 52)
        }
        .disabled(isLoading)
    }
}
