import SwiftUI

struct FSGlassButton<Content: View>: View {
    let action: () -> Void
    var size: CGFloat = 36
    var accent: Bool = false
    @Environment(\.fsTheme) var t
    @ViewBuilder let content: () -> Content

    var body: some View {
        Button(action: action) {
            content()
                .frame(width: size, height: size)
        }
        .glassEffect(.regular.interactive(), in: Circle())
        .tint(accent ? t.accent : nil)
    }
}
