import SwiftUI

/// Horizontal rail of new matches + vertical list of conversations happens on
/// the Chats tab. This screen focuses on "new matches" — people you can still
/// only say hi to.
struct MatchesListView: View {
    @Environment(AppState.self) private var appState
    @State private var matches: [Match] = []
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()
                Group {
                    if isLoading {
                        ProgressView()
                    } else if matches.isEmpty {
                        EmptyMatchesView()
                    } else {
                        content
                    }
                }
            }
            .navigationTitle("Мэтчи")
            .task { await load() }
            .refreshable { await load() }
        }
    }

    private func load() async {
        isLoading = matches.isEmpty
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

    private var content: some View {
        ScrollView {
            LazyVGrid(columns: [GridItem(.adaptive(minimum: 120), spacing: AppSpacing.m)], spacing: AppSpacing.m) {
                ForEach(matches) { match in
                    NavigationLink(value: match) {
                        MatchCard(match: match)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(AppSpacing.l)
        }
        .navigationDestination(for: Match.self) { match in
            ChatView(match: match)
        }
    }
}

private struct MatchCard: View {
    @Environment(AppState.self) private var appState
    let match: Match

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            ZStack(alignment: .topTrailing) {
                RoundedRectangle(cornerRadius: AppRadius.m)
                    .fill(
                        LinearGradient(
                            colors: [AppColor.accent.opacity(0.7), AppColor.accentSoft],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .aspectRatio(3/4, contentMode: .fit)
                    .overlay(
                        Image(systemName: "person.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.white.opacity(0.5))
                    )
                // Top-right: unread badge or online dot
                VStack {
                    HStack {
                        Spacer()
                        if match.hasUnread {
                            Circle().fill(AppColor.accent).frame(width: 12, height: 12)
                                .padding(AppSpacing.s)
                        }
                    }
                    Spacer()
                    HStack {
                        Spacer()
                        if appState.presence.isOnline(match.profile.id) {
                            OnlineStatusBadge(size: 12).padding(AppSpacing.s)
                        }
                    }
                }
            }
            Text("\(match.profile.name), \(match.profile.age)")
                .font(AppTypography.bodyBold)
                .foregroundStyle(AppColor.textPrimary)
            Text(match.profile.city)
                .font(AppTypography.caption)
                .foregroundStyle(AppColor.textSecondary)
        }
    }
}

private struct EmptyMatchesView: View {
    var body: some View {
        VStack(spacing: AppSpacing.m) {
            Text("✨").font(.system(size: 64))
            Text("Пока нет мэтчей")
                .font(AppTypography.title2)
                .foregroundStyle(AppColor.textPrimary)
            Text("Лайкни кого-нибудь в ленте — если будет взаимно, человек появится здесь.")
                .font(AppTypography.subheadline)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
        }
    }
}

#Preview {
    MatchesListView().environment(AppState())
}
