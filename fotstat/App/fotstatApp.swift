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
        .preferredColorScheme(themePreference == "system" ? nil : resolvedScheme)
    }
}
