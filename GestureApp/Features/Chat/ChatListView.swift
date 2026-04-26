import SwiftUI

struct ChatListView: View {
    @Environment(AppState.self) private var appState
    @State private var matches: [Match] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()
                Group {
                    if isLoading && matches.isEmpty {
                        ProgressView()
                    } else if matches.isEmpty {
                        EmptyChatsView()
                    } else {
                        list
                    }
                }
            }
            .navigationTitle("Чаты")
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private var list: some View {
        List(matches) { match in
            NavigationLink(value: match) {
                ChatListRow(match: match)
            }
            .listRowBackground(AppColor.background)
            .listRowSeparatorTint(AppColor.divider)
        }
        .listStyle(.plain)
        .scrollContentBackground(.hidden)
        .navigationDestination(for: Match.self) { match in
            ChatView(match: match)
        }
    }

    private func load() async {
        isLoading = true
        defer { isLoading = false }
        if APIConfig.isConfigured {
            if let fetched = try? await appState.chat.fetchMatches() {
                matches = fetched
            }
        } else {
            try? await Task.sleep(for: .milliseconds(200))
            matches = MockData.sampleMatches
        }
    }
}

private struct ChatListRow: View {
    @Environment(AppState.self) private var appState
    let match: Match

    var body: some View {
        HStack(spacing: AppSpacing.m) {
            ZStack(alignment: .bottomTrailing) {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColor.accent, AppColor.accentSoft],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 56, height: 56)
                    .overlay(
                        Text(String(match.profile.name.prefix(1)))
                            .font(AppTypography.headline)
                            .foregroundStyle(.white)
                    )
                if appState.presence.isOnline(match.profile.id) {
                    OnlineStatusBadge(size: 14).offset(x: 2, y: 2)
                }
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(match.profile.name)
                    .font(AppTypography.bodyBold)
                    .foregroundStyle(AppColor.textPrimary)
                Text(match.lastMessagePreview ?? "Поздоровайся первым")
                    .font(AppTypography.subheadline)
                    .foregroundStyle(AppColor.textSecondary)
                    .lineLimit(1)
            }

            Spacer()

            if match.hasUnread {
                Circle().fill(AppColor.accent).frame(width: 10, height: 10)
            }
        }
        .padding(.vertical, AppSpacing.xs)
    }
}

private struct EmptyChatsView: View {
    var body: some View {
        VStack(spacing: AppSpacing.m) {
            Text("💬").font(.system(size: 64))
            Text("Здесь будут чаты")
                .font(AppTypography.title2)
                .foregroundStyle(AppColor.textPrimary)
            Text("Начни с лайков в ленте.")
                .font(AppTypography.subheadline)
                .foregroundStyle(AppColor.textSecondary)
        }
    }
}

#Preview {
    ChatListView().environment(AppState())
}
