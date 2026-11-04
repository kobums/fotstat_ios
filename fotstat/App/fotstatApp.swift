import SwiftUI
import UIKit

extension UINavigationController {
    override open func viewDidLoad() {
        super.viewDidLoad()
        interactivePopGestureRecognizer?.delegate = nil
    }
}

@main
struct fotstatApp: App {
    @StateObject private var authManager = AuthManager.shared

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
        }
    }
}

struct RootView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.colorScheme) var colorScheme
    @AppStorage("themePreference") var themePreference: String = "system"
    @State private var containerSize: CGSize = .zero

    private var resolvedScheme: ColorScheme {
        switch themePreference {
        case "dark": return .dark
        case "light": return .light
        default: return colorScheme
        }
    }

    var body: some View {
        Group {
            if authManager.isLoggedIn {
                HomeView()
            } else {
                LoginView()
            }
        }
        .environment(\.fsTheme, FSTheme(mode: resolvedScheme))
        .environment(\.fsContainerSize, containerSize)
        // 키보드가 뜰 때 크기가 줄어들지 않도록 키보드 영역은 빼고 측정
        .background {
            Color.clear
                .ignoresSafeArea(.keyboard)
                .onGeometryChange(for: CGSize.self) { $0.size } action: { containerSize = $0 }
        }
        .preferredColorScheme(themePreference == "system" ? nil : resolvedScheme)
    }
}
