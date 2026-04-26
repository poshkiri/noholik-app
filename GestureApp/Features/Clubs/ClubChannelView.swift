import SwiftUI
import UIKit

struct ClubChannelView: View {
    @Environment(AppState.self) private var appState
    let club: Club
    let channel: ClubChannel

    @State private var vm: ClubChannelViewModel?

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            if let vm {
                VStack(spacing: 0) {
                    messageList(vm: vm)
                    Divider().background(AppColor.divider)
                    inputBar(vm: vm)
                }
            } else {
                ProgressView()
            }
        }
        .navigationTitle("#\(channel.name)")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            if vm == nil {
                let uid = appState.currentUserID ?? MockData.currentUserID
                let name = appState.myProfile?.name ?? "Вы"
                vm = ClubChannelViewModel(
                    channelId: channel.id,
                    currentUserId: uid,
                    currentUserName: name,
                    service: appState.clubs
                )
            }
        }
        .task { await vm?.load() }
    }

    // MARK: - Messages

    private func messageList(vm: ClubChannelViewModel) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(vm.messages) { message in
                        ClubMessageRow(
                            message: message,
                            isMine: message.authorId == vm.currentUserId,
                            onReact: { emoji in
                                Task { await vm.react(emoji: emoji, to: message) }
                            }
                        )
                        .id(message.id)
                    }
                }
                .padding(.vertical, AppSpacing.s)
            }
            .scrollDismissesKeyboard(.interactively)
            .onChange(of: vm.messages.count) { _, _ in
                if let last = vm.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    // MARK: - Input bar

    private func inputBar(vm: ClubChannelViewModel) -> some View {
        @Bindable var vm = vm
        let isBlank = vm.draft.trimmingCharacters(in: .whitespaces).isEmpty
        return HStack(spacing: AppSpacing.s) {
            TextField("Сообщение в #\(channel.name)", text: $vm.draft, axis: .vertical)
                .lineLimit(1...4)
                .font(AppTypography.body)
                .padding(.horizontal, AppSpacing.m)
                .padding(.vertical, AppSpacing.s)
                .background(AppColor.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.l))

            Button {
                UIImpactFeedbackGenerator(style: .light).impactOccurred()
                Task { await vm.send() }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(isBlank ? AppColor.accent.opacity(0.4) : AppColor.accent)
                    .clipShape(Circle())
            }
            .disabled(isBlank)
        }
        .padding(AppSpacing.m)
        .background(AppColor.surface)
    }
}

// MARK: - Message row

private struct ClubMessageRow: View {
    let message: ClubMessage
    let isMine: Bool
    let onReact: (String) -> Void

    @State private var showReactPicker = false
    private let quickEmoji = ["🤟", "❤️", "😂", "😮", "👍", "🔥"]

    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.s) {
            if !isMine {
                authorAvatar
            }

            VStack(alignment: isMine ? .trailing : .leading, spacing: 4) {
                if !isMine {
                    Text(message.authorName)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                }

                Text(message.text)
                    .font(AppTypography.body)
                    .foregroundStyle(isMine ? AppColor.textOnAccent : AppColor.textPrimary)
                    .padding(.horizontal, AppSpacing.m)
                    .padding(.vertical, AppSpacing.s)
                    .background(isMine ? AppColor.accent : AppColor.surface)
                    .clipShape(
                        .rect(
                            topLeadingRadius: AppRadius.l,
                            bottomLeadingRadius: isMine ? AppRadius.l : AppRadius.xs,
                            bottomTrailingRadius: isMine ? AppRadius.xs : AppRadius.l,
                            topTrailingRadius: AppRadius.l
                        )
                    )

                // Reactions
                if !message.reactions.isEmpty {
                    reactionsBar
                }
            }

            if isMine {
                Spacer(minLength: 40)
            }
        }
        .padding(.horizontal, AppSpacing.m)
        .padding(.vertical, AppSpacing.xs)
        .contentShape(Rectangle())
        .onLongPressGesture {
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            showReactPicker = true
        }
        .confirmationDialog("Реакция", isPresented: $showReactPicker) {
            ForEach(quickEmoji, id: \.self) { emoji in
                Button(emoji) { onReact(emoji) }
            }
        }
    }

    private var authorAvatar: some View {
        Circle()
            .fill(LinearGradient(colors: [AppColor.accent, AppColor.accentSoft],
                                 startPoint: .topLeading, endPoint: .bottomTrailing))
            .frame(width: 36, height: 36)
            .overlay(
                Text(String(message.authorName.prefix(1)))
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
            )
    }

    private var reactionsBar: some View {
        HStack(spacing: 4) {
            ForEach(topReactions, id: \.emoji) { item in
                Button {
                    onReact(item.emoji)
                } label: {
                    HStack(spacing: 3) {
                        Text(item.emoji).font(.caption)
                        Text("\(item.count)").font(.caption2).foregroundStyle(AppColor.textSecondary)
                    }
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(AppColor.surfaceElevated)
                    .clipShape(Capsule())
                    .overlay(Capsule().strokeBorder(AppColor.divider, lineWidth: 0.5))
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var topReactions: [(emoji: String, count: Int)] {
        message.reactions
            .sorted { $0.value > $1.value }
            .prefix(3)
            .map { (emoji: $0.key, count: $0.value) }
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class ClubChannelViewModel {
    let channelId: UUID
    let currentUserId: UUID
    let currentUserName: String
    var messages: [ClubMessage] = []
    var draft: String = ""

    private let service: ClubService

    init(channelId: UUID, currentUserId: UUID, currentUserName: String, service: ClubService) {
        self.channelId = channelId
        self.currentUserId = currentUserId
        self.currentUserName = currentUserName
        self.service = service
    }

    func load() async {
        messages = (try? await service.fetchMessages(channelId: channelId)) ?? []
    }

    func send() async {
        let text = draft.trimmingCharacters(in: .whitespaces)
        guard !text.isEmpty else { return }
        draft = ""
        if let msg = try? await service.send(
            text: text, channelId: channelId,
            authorId: currentUserId, authorName: currentUserName
        ) {
            messages.append(msg)
        }
    }

    func react(emoji: String, to message: ClubMessage) async {
        try? await service.react(emoji: emoji, messageId: message.id, channelId: channelId)
        if let idx = messages.firstIndex(where: { $0.id == message.id }) {
            messages[idx].reactions[emoji, default: 0] += 1
        }
    }
}
