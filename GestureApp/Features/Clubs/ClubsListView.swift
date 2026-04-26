import SwiftUI

struct ClubsListView: View {
    @Environment(AppState.self) private var appState
    @State private var vm = ClubsViewModel()
    @State private var isCreatePresented = false
    @State private var searchText = ""

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()

                VStack(spacing: 0) {
                    picker
                    clubList
                }
            }
            .navigationTitle("Клубы")
            .searchable(text: $searchText, prompt: "Поиск клуба")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isCreatePresented = true
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.title3)
                            .foregroundStyle(AppColor.accent)
                    }
                }
            }
            .task { await vm.load(service: appState.clubs) }
            .sheet(isPresented: $isCreatePresented) {
                CreateClubView { club in
                    vm.insert(club)
                }
                .environment(appState)
            }
            .navigationDestination(for: Club.self) { club in
                ClubDetailView(club: club)
                    .environment(appState)
            }
        }
    }

    // MARK: - Picker

    private var picker: some View {
        Picker("", selection: $vm.tab) {
            Text("Все клубы").tag(ClubsViewModel.Tab.all)
            Text("Мои клубы").tag(ClubsViewModel.Tab.mine)
        }
        .pickerStyle(.segmented)
        .padding(.horizontal, AppSpacing.l)
        .padding(.vertical, AppSpacing.s)
    }

    // MARK: - List

    @ViewBuilder
    private var clubList: some View {
        let items = vm.filtered(search: searchText)
        if vm.isLoading {
            Spacer()
            ProgressView()
            Spacer()
        } else if items.isEmpty {
            emptyState
        } else {
            ScrollView {
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: AppSpacing.m) {
                    ForEach(items) { club in
                        NavigationLink(value: club) {
                            ClubCard(club: club) {
                                Task { await vm.toggleJoin(club: club, service: appState.clubs) }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(AppSpacing.l)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: AppSpacing.m) {
            Spacer()
            Text("🤟").font(.system(size: 56))
            Text(vm.tab == .mine ? "Ты ещё не вступил в клубы" : "Клубы не найдены")
                .font(AppTypography.title2)
                .foregroundStyle(AppColor.textPrimary)
            Text(vm.tab == .mine ? "Загляни в «Все клубы» и найди своё сообщество." : "Попробуй другой запрос.")
                .font(AppTypography.subheadline)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            Spacer()
        }
    }
}

// MARK: - Club card

private struct ClubCard: View {
    let club: Club
    let onJoinToggle: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text(club.emoji)
                .font(.system(size: 40))
                .frame(maxWidth: .infinity, alignment: .leading)

            Text(club.name)
                .font(AppTypography.bodyBold)
                .foregroundStyle(AppColor.textPrimary)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)

            HStack(spacing: 4) {
                Image(systemName: "person.2.fill")
                    .font(.caption2)
                Text("\(club.memberCount)")
                    .font(AppTypography.caption)
            }
            .foregroundStyle(AppColor.textSecondary)

            Spacer()

            Button(action: onJoinToggle) {
                Text(club.isJoined ? "Вступил" : "Вступить")
                    .font(AppTypography.caption)
                    .fontWeight(.semibold)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(club.isJoined ? AppColor.surface : AppColor.accent)
                    .foregroundStyle(club.isJoined ? AppColor.textSecondary : AppColor.textOnAccent)
                    .clipShape(Capsule())
                    .overlay(
                        Capsule()
                            .strokeBorder(club.isJoined ? AppColor.divider : .clear, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
        }
        .padding(AppSpacing.m)
        .frame(minHeight: 170, alignment: .topLeading)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.l))
        .shadow(color: .black.opacity(0.06), radius: 6, y: 3)
    }
}

// MARK: - ViewModel

@Observable
@MainActor
final class ClubsViewModel {
    enum Tab { case all, mine }

    var tab: Tab = .all
    var clubs: [Club] = []
    var isLoading = false

    func load(service: ClubService) async {
        guard clubs.isEmpty else { return }
        isLoading = true
        clubs = (try? await service.fetchAllClubs()) ?? []
        isLoading = false
    }

    func insert(_ club: Club) {
        clubs.insert(club, at: 0)
    }

    func filtered(search: String) -> [Club] {
        let base = tab == .all ? clubs : clubs.filter(\.isJoined)
        guard !search.isEmpty else { return base }
        let q = search.lowercased()
        return base.filter {
            $0.name.lowercased().contains(q) ||
            $0.description.lowercased().contains(q) ||
            $0.category.title.lowercased().contains(q)
        }
    }

    func toggleJoin(club: Club, service: ClubService) async {
        guard let idx = clubs.firstIndex(where: { $0.id == club.id }) else { return }
        if clubs[idx].isJoined {
            try? await service.leave(clubId: club.id)
            clubs[idx].isJoined = false
            clubs[idx].memberCount -= 1
        } else {
            if let updated = try? await service.join(clubId: club.id) {
                clubs[idx] = updated
            }
        }
    }
}

#Preview {
    ClubsListView().environment(AppState())
}
