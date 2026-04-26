import SwiftUI

@main
struct GestureAppApp: App {

    @State private var appState = AppState.live()

    var body: some Scene {
        WindowGroup {
            AppRootView()
                .environment(appState)
                .task { await appState.bootstrap() }
        }
    }
}

private struct AppRootView: View {
    @Environment(AppState.self) private var appState

    var body: some View {
        switch appState.phase {
        case .splash:
            SplashView()
        case .signedOut:
            SignInView()
        case .onboarding:
            OnboardingFlowView()
        case .signedIn:
            MainTabView()
        }
    }
}

private struct SplashView: View {
    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            VStack(spacing: 20) {
                Text("🤟")
                    .font(.system(size: 72))
                ProgressView()
                    .tint(AppColor.accent)
                    .scaleEffect(1.2)
            }
        }
    }
}
