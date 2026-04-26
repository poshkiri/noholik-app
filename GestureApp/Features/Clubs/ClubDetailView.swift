import SwiftUI

struct ClubDetailView: View {
    @Environment(AppState.self) private var appState
    @State private var club: Club

    init(club: Club) {
        _club = State(initialValue: club)
    }

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: 0) {
                    header
                    Divider().background(AppColor.divider)
                    channelList
                }
            }
        }
        .navigationTitle(club.name)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                joinButton
            }
        }
        .navigationDestination(for: ClubChannelDestination.self) { dest in
            ClubChannelView(club: dest.club, channel: dest.channel)
                .environment(appState)
        }
    }

    // MARK: - Header

    private var header: some View {
        VStack(spacing: AppSpacing.m) {
            ZStack {
                Circle()
                    .fill(
                        LinearGradient(
                            colors: [AppColor.accent.opacity(0.15), AppColor.accentSoft],
                            startPoint: .topLeading, endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 96, height: 96)
                Text(club.emoji).font(.system(size: 48))
            }

            VStack(spacing: AppSpacing.xs) {
                Text(club.name)
                    .font(AppTypography.title)
                    .foregroundStyle(AppColor.textPrimary)

                HStack(spacing: AppSpacing.s) {
                    Label(club.category.title, systemImage: "tag")
                    Text("·")
                    Label("\(club.memberCount) участников", systemImage: "person.2.fill")
                }
                .font(AppTypography.caption)
                .foregroundStyle(AppColor.textSecondary)
            }

            Text(club.description)
                .font(AppTypography.body)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.l)
        }
        .padding(.vertical, AppSpacing.xl)
    }

    // MARK: - Channels

    private var channelList: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Каналы")
                .font(AppTypography.caption)
                .foregroundStyle(AppColor.textSecondary)
                .padding(.horizontal, AppSpacing.l)
                .padding(.top, AppSpacing.l)
                .padding(.bottom, AppSpacing.xs)

            ForEach(club.channels) { channel in
                NavigationLink(value: ClubChannelDestination(club: club, channel: channel)) {
                    ChannelRow(channel: channel)
                }
                .buttonStyle(.plain)
                Divider()
                    .padding(.leading, AppSpacing.l + 32)
                    .background(AppColor.divider)
            }
        }
        .padding(.bottom, AppSpacing.xl)
    }

    // MARK: - Join button

    private var joinButton: some View {
        Button {
            Task {
                if club.isJoined {
                    try? await appState.clubs.leave(clubId: club.id)
                    club.isJoined = false
                    club.memberCount -= 1
                } else {
                    if let updated = try? await appState.clubs.join(clubId: club.id) {
                        club = updated
                    }
                }
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
            }
        } label: {
            Text(club.isJoined ? "Выйти" : "Вступить")
                .font(AppTypography.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, AppSpacing.m)
                .padding(.vertical, 6)
                .background(club.isJoined ? AppColor.surface : AppColor.accent)
                .foregroundStyle(club.isJoined ? AppColor.textSecondary : AppColor.textOnAccent)
                .clipShape(Capsule())
                .overlay(Capsule().strokeBorder(club.isJoined ? AppColor.divider : .clear, lineWidth: 1))
        }
    }
}

// MARK: - Channel row

private struct ChannelRow: View {
    let channel: ClubChannel

    var body: some View {
        HStack(spacing: AppSpacing.m) {
            Image(systemName: channel.kind.icon)
                .font(.body)
                .foregroundStyle(AppColor.accent)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(channel.name)
                    .font(AppTypography.body)
                    .foregroundStyle(AppColor.textPrimary)
                if let preview = channel.lastMessagePreview {
                    Text(preview)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            if channel.unreadCount > 0 {
                Text("\(channel.unreadCount)")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(AppColor.accent)
                    .clipShape(Capsule())
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(AppColor.textSecondary)
        }
        .padding(.horizontal, AppSpacing.l)
        .padding(.vertical, AppSpacing.m)
        .contentShape(Rectangle())
    }
}

// MARK: - Navigation helper

struct ClubChannelDestination: Hashable {
    let club: Club
    let channel: ClubChannel
}
