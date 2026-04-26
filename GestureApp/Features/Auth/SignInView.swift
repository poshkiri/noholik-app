import SwiftUI
import UIKit

struct SignInView: View {
    @Environment(AppState.self) private var appState
    @State private var vm: SignInViewModel?
    @AppStorage("legal_acceptsPrivacyPolicy") private var acceptsPrivacyPolicy = false
    @AppStorage("legal_acceptsSensitiveData") private var acceptsSensitiveData = false

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            if let vm {
                VStack(spacing: AppSpacing.xl) {
                    header
                    Spacer(minLength: AppSpacing.xl)
                    signInContent(vm: vm)
                    Spacer()
                    disclaimer
                }
                .padding(.horizontal, AppSpacing.xl)
                .padding(.vertical, AppSpacing.xl)
            } else {
                ProgressView()
                    .tint(AppColor.accent)
                    .scaleEffect(1.2)
            }
        }
        // Prefer `.task` over `.onAppear`: on some OS versions the latter runs late → empty screen.
        .task { if vm == nil { vm = makeViewModel() } }
    }

    private func makeViewModel() -> SignInViewModel {
        SignInViewModel(auth: appState.auth) { [appState] userID in
            await appState.didSignIn(userID: userID)
        }
    }

    private var canStartSignIn: Bool {
        acceptsPrivacyPolicy && acceptsSensitiveData
    }

    private var header: some View {
        VStack(spacing: AppSpacing.s) {
            Text("🤟").font(.system(size: 64))
            Text("Добро пожаловать")
                .font(AppTypography.largeTitle)
                .foregroundStyle(AppColor.textPrimary)
            Text("Знакомства для глухих, слабослышащих и их друзей")
                .font(AppTypography.subheadline)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
        }
    }

    private func signInContent(vm: SignInViewModel) -> some View {
        VStack(spacing: AppSpacing.l) {
            PrimaryButton(
                title: "Войти с VK ID",
                systemImage: "person.crop.circle",
                isLoading: vm.isSigningInVK,
                isEnabled: !vm.isSigningInVK && !vm.isSigningInApple && canStartSignIn
            ) {
                let presenter = UIApplication.shared.gesture_topViewController
                Task { await vm.signInWithVK(presenter: presenter) }
            }

            HStack {
                Rectangle().fill(AppColor.divider).frame(height: 1)
                Text("или").font(AppTypography.caption).foregroundStyle(AppColor.textSecondary)
                Rectangle().fill(AppColor.divider).frame(height: 1)
            }

            PrimaryButton(
                title: "Войти через Apple",
                systemImage: "apple.logo",
                style: .outlined,
                isLoading: vm.isSigningInApple,
                isEnabled: !vm.isSigningInVK && !vm.isSigningInApple && canStartSignIn
            ) {
                Task { await vm.signInWithApple() }
            }

            VStack(alignment: .leading, spacing: AppSpacing.s) {
                Toggle(isOn: $acceptsPrivacyPolicy) {
                    Text("Я согласен с обработкой персональных данных и политикой конфиденциальности")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                }
                Toggle(isOn: $acceptsSensitiveData) {
                    Text("Я согласен на обработку данных профиля, включая сведения о статусе слуха")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                }
            }

            if let err = vm.errorMessage {
                Text(err)
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.danger)
                    .multilineTextAlignment(.center)
            }

            // ── Simulator-only bypass ──────────────────────────────────────
            #if targetEnvironment(simulator)
            Button("🛠 Войти как тестовый пользователь") {
                Task { await appState.didSignIn(userID: UUID(uuidString: "00000000-0000-0000-0000-000000000001")!) }
            }
            .font(AppTypography.caption)
            .foregroundStyle(AppColor.textSecondary)
            .padding(.top, AppSpacing.s)
            #endif
        }
    }

    private var disclaimer: some View {
        Text("Вход доступен только после согласия на обработку данных. Перед релизом в России замените этот текст ссылками на политику и согласие. 18+")
            .font(AppTypography.caption)
            .foregroundStyle(AppColor.textSecondary)
            .multilineTextAlignment(.center)
    }
}

#Preview {
    SignInView().environment(AppState())
}
