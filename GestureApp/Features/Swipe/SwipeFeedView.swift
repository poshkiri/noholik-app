import SwiftUI
import UIKit

struct SwipeFeedView: View {
    @Environment(AppState.self) private var appState
    @State private var vm: SwipeFeedViewModel?

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()
                if let vm {
                    content(vm: vm)
                        .task { await vm.loadIfNeeded() }
                }
            }
            .navigationTitle("Лента")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear { if vm == nil { vm = SwipeFeedViewModel(service: appState.swipe) } }
        .sheet(item: Binding(
            get: { vm?.matchedProfile },
            set: { if $0 == nil { vm?.dismissMatch() } }
        )) { profile in
            MatchCelebrationView(profile: profile)
                .presentationDetents([.medium])
        }
    }

    @ViewBuilder
    private func content(vm: SwipeFeedViewModel) -> some View {
        switch vm.status {
        case .loading:
            ProgressView()
        case .empty:
            EmptyFeedView { Task { await vm.reload() } }
        case .error(let message):
            ErrorView(message: message) { Task { await vm.reload() } }
        case .idle:
            cards(vm: vm)
        }
    }

    private func cards(vm: SwipeFeedViewModel) -> some View {
        VStack(spacing: AppSpacing.l) {
            ZStack {
                ForEach(Array(vm.candidates.prefix(3).enumerated()), id: \.element.id) { index, profile in
                    ProfileCardView(profile: profile) { decision in
                        Task { await vm.swipe(decision, on: profile) }
                    }
                    .scaleEffect(1 - CGFloat(index) * 0.03)
                    .offset(y: CGFloat(index) * 10)
                    .zIndex(Double(-index))
                    .allowsHitTesting(index == 0)
                }
            }
            .padding(.horizontal, AppSpacing.l)

            actionButtons(vm: vm)
                .padding(.bottom, AppSpacing.l)
        }
    }

    private func actionButtons(vm: SwipeFeedViewModel) -> some View {
        HStack(spacing: AppSpacing.xl) {
            circleButton(system: "xmark", color: AppColor.danger) {
                if let p = vm.candidates.first { Task { await vm.swipe(.pass, on: p) } }
            }
            circleButton(system: "star.fill", color: AppColor.warning, size: 56) {
                if let p = vm.candidates.first { Task { await vm.swipe(.superLike, on: p) } }
            }
            circleButton(system: "heart.fill", color: AppColor.success) {
                if let p = vm.candidates.first { Task { await vm.swipe(.like, on: p) } }
            }
        }
    }

    private func circleButton(system: String, color: Color, size: CGFloat = 64, action: @escaping () -> Void) -> some View {
        Button {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            action()
        } label: {
            Image(systemName: system)
                .font(.system(size: size * 0.4, weight: .bold))
                .foregroundStyle(color)
                .frame(width: size, height: size)
                .background(AppColor.surface)
                .clipShape(Circle())
                .shadow(color: .black.opacity(0.08), radius: 6, y: 3)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Helpers

private struct EmptyFeedView: View {
    let reload: () -> Void
    var body: some View {
        VStack(spacing: AppSpacing.m) {
            Text("🌅").font(.system(size: 64))
            Text("Пока всё")
                .font(AppTypography.title2)
                .foregroundStyle(AppColor.textPrimary)
            Text("Мы покажем новые профили позже.")
                .font(AppTypography.subheadline)
                .foregroundStyle(AppColor.textSecondary)
            PrimaryButton(title: "Обновить", style: .outlined, action: reload)
                .padding(.top, AppSpacing.l)
                .padding(.horizontal, AppSpacing.xxxl)
        }
    }
}

private struct ErrorView: View {
    let message: String
    let retry: () -> Void
    var body: some View {
        VStack(spacing: AppSpacing.m) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppColor.warning)
            Text(message)
                .font(AppTypography.body)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
            PrimaryButton(title: "Повторить", style: .outlined, action: retry)
                .padding(.horizontal, AppSpacing.xxxl)
        }
        .padding()
    }
}

private struct MatchCelebrationView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss
    let profile: Profile

    @State private var openChat = false

    private var matchForChat: Match {
        Match(id: UUID(), profile: profile, createdAt: .now,
              lastMessagePreview: nil, lastMessageAt: nil, hasUnread: false)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: AppSpacing.l) {
                Spacer()
                Text("🤟 💬").font(.system(size: 64))
                Text("Это мэтч!")
                    .font(AppTypography.largeTitle)
                    .foregroundStyle(AppColor.accent)
                Text("Вы понравились друг другу с \(profile.name).")
                    .font(AppTypography.body)
                    .foregroundStyle(AppColor.textPrimary)
                    .multilineTextAlignment(.center)
                Spacer()
                PrimaryButton(title: "Написать сообщение") {
                    openChat = true
                }
                .padding(.horizontal, AppSpacing.xl)
                Button("Позже") { dismiss() }
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                    .padding(.bottom, AppSpacing.l)
            }
            .padding()
            .navigationDestination(isPresented: $openChat) {
                ChatView(match: matchForChat).environment(appState)
            }
        }
    }
}

#Preview {
    SwipeFeedView().environment(AppState())
}
