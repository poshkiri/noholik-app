import SwiftUI

struct ChatView: View {
    @Environment(AppState.self) private var appState
    let match: Match

    @State private var vm: ChatViewModel?

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            if let vm {
                VStack(spacing: 0) {
                    messageList(vm: vm)
                    Divider().background(AppColor.divider)
                    inputBar(vm: vm)
                }
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                OnlineTitleView(profile: match.profile)
                    .environment(appState)
            }
        }
        .onAppear { if vm == nil { vm = makeViewModel() } }
        .task { await vm?.load() }
    }

    private func makeViewModel() -> ChatViewModel {
        ChatViewModel(
            match: match,
            currentUserID: appState.currentUserID ?? MockData.currentUserID,
            service: appState.chat
        )
    }

    private func messageList(vm: ChatViewModel) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: AppSpacing.s) {
                    ForEach(vm.messages) { message in
                        MessageBubble(message: message, isMine: vm.isMine(message))
                            .id(message.id)
                    }
                }
                .padding(.horizontal, AppSpacing.l)
                .padding(.vertical, AppSpacing.m)
            }
            .onChange(of: vm.messages.count) { _, _ in
                if let last = vm.messages.last {
                    withAnimation { proxy.scrollTo(last.id, anchor: .bottom) }
                }
            }
        }
    }

    private func inputBar(vm: ChatViewModel) -> some View {
        @Bindable var vm = vm
        return HStack(spacing: AppSpacing.s) {
            Button {
                // TODO: open video recorder sheet
            } label: {
                Image(systemName: "video.fill")
                    .font(.title3)
                    .foregroundStyle(AppColor.accent)
                    .frame(width: 40, height: 40)
                    .background(AppColor.accentSoft)
                    .clipShape(Circle())
            }

            TextField("Сообщение", text: $vm.draft, axis: .vertical)
                .lineLimit(1...4)
                .padding(.horizontal, AppSpacing.m)
                .padding(.vertical, AppSpacing.s)
                .background(AppColor.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.l))

            Button {
                Task { await vm.sendText() }
            } label: {
                Image(systemName: "arrow.up")
                    .font(.title3.weight(.bold))
                    .foregroundStyle(.white)
                    .frame(width: 40, height: 40)
                    .background(AppColor.accent)
                    .clipShape(Circle())
            }
            .disabled(vm.draft.trimmingCharacters(in: .whitespaces).isEmpty)
            .opacity(vm.draft.trimmingCharacters(in: .whitespaces).isEmpty ? 0.5 : 1)
        }
        .padding(AppSpacing.m)
        .background(AppColor.surface)
    }
}

// MARK: - Message bubble

struct MessageBubble: View {
    let message: Message
    let isMine: Bool

    var body: some View {
        HStack {
            if isMine { Spacer(minLength: 40) }

            content
                .padding(.horizontal, AppSpacing.m)
                .padding(.vertical, AppSpacing.s)
                .background(isMine ? AppColor.accent : AppColor.surfaceElevated)
                .foregroundStyle(isMine ? AppColor.textOnAccent : AppColor.textPrimary)
                .clipShape(
                    .rect(
                        topLeadingRadius: AppRadius.l,
                        bottomLeadingRadius: isMine ? AppRadius.l : AppRadius.xs,
                        bottomTrailingRadius: isMine ? AppRadius.xs : AppRadius.l,
                        topTrailingRadius: AppRadius.l
                    )
                )

            if !isMine { Spacer(minLength: 40) }
        }
    }

    @ViewBuilder
    private var content: some View {
        switch message.kind {
        case .text(let text):
            Text(text).font(AppTypography.body)
        case .video(_, let duration, _):
            HStack(spacing: AppSpacing.s) {
                Image(systemName: "play.circle.fill").font(.title2)
                Text("Видео · \(Int(duration)) сек").font(AppTypography.body)
            }
        case .image:
            Image(systemName: "photo")
                .font(.largeTitle)
        }
    }
}

// MARK: - Online title

private struct OnlineTitleView: View {
    @Environment(AppState.self) private var appState
    let profile: Profile

    var body: some View {
        VStack(spacing: 1) {
            Text(profile.name)
                .font(AppTypography.bodyBold)
                .foregroundStyle(AppColor.textPrimary)

            let status = appState.presence.statusText(for: profile)
            if !status.isEmpty {
                HStack(spacing: 4) {
                    if appState.presence.isOnline(profile.id) {
                        Circle().fill(.green).frame(width: 6, height: 6)
                    }
                    Text(status)
                        .font(.caption2)
                        .foregroundStyle(
                            appState.presence.isOnline(profile.id) ? .green : AppColor.textSecondary
                        )
                }
            }
        }
        .animation(.easeInOut(duration: 0.3), value: appState.presence.isOnline(profile.id))
    }
}

#Preview {
    NavigationStack {
        ChatView(match: MockData.sampleMatches[0]).environment(AppState())
    }
}
