import SwiftUI

struct CreateClubView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    let onCreated: (Club) -> Void

    @State private var name = ""
    @State private var description = ""
    @State private var selectedEmoji = "🤟"
    @State private var category: ClubCategory = .deafCulture
    @State private var isCreating = false
    @State private var errorMessage: String?

    private let emojiGrid = ["🤟","👋","🎬","🎮","💙","🌆","🎯","🎤","📚","🍕","🏃","🎨","🌿","🐾","✈️","🎧"]

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.l) {
                        emojiSection
                        nameSection
                        descriptionSection
                        categorySection
                    }
                    .padding(AppSpacing.l)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Новый клуб")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                        .foregroundStyle(AppColor.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await create() }
                    } label: {
                        if isCreating {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text("Создать").fontWeight(.semibold)
                        }
                    }
                    .disabled(!canCreate || isCreating)
                    .foregroundStyle(canCreate ? AppColor.accent : AppColor.textSecondary)
                }
            }
            .alert("Не удалось создать клуб", isPresented: Binding(
                get: { errorMessage != nil },
                set: { if !$0 { errorMessage = nil } }
            ), presenting: errorMessage) { _ in
                Button("OK", role: .cancel) { errorMessage = nil }
            } message: { Text($0) }
        }
    }

    // MARK: - Emoji

    private var emojiSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Label("Иконка клуба", systemImage: "face.smiling")
                .font(AppTypography.caption)
                .foregroundStyle(AppColor.textSecondary)

            LazyVGrid(columns: Array(repeating: GridItem(.flexible()), count: 8), spacing: AppSpacing.s) {
                ForEach(emojiGrid, id: \.self) { emoji in
                    Button {
                        selectedEmoji = emoji
                    } label: {
                        Text(emoji)
                            .font(.title2)
                            .frame(width: 44, height: 44)
                            .background(selectedEmoji == emoji ? AppColor.accentSoft : AppColor.surface)
                            .clipShape(RoundedRectangle(cornerRadius: AppRadius.s))
                            .overlay(
                                RoundedRectangle(cornerRadius: AppRadius.s)
                                    .strokeBorder(selectedEmoji == emoji ? AppColor.accent : .clear, lineWidth: 2)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Name

    private var nameSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Название")
                .font(AppTypography.caption)
                .foregroundStyle(AppColor.textSecondary)
            TextField("Например: Глухие в Питере", text: $name)
                .font(AppTypography.body)
                .padding(AppSpacing.m)
                .background(AppColor.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.m))
            Text("\(name.count)/40")
                .font(.caption2)
                .foregroundStyle(name.count > 40 ? AppColor.danger : AppColor.textSecondary)
                .frame(maxWidth: .infinity, alignment: .trailing)
        }
        .onChange(of: name) { _, new in
            if new.count > 40 { name = String(new.prefix(40)) }
        }
    }

    // MARK: - Description

    private var descriptionSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("Описание")
                .font(AppTypography.caption)
                .foregroundStyle(AppColor.textSecondary)
            TextField("О чём этот клуб?", text: $description, axis: .vertical)
                .lineLimit(3...5)
                .font(AppTypography.body)
                .padding(AppSpacing.m)
                .background(AppColor.surfaceElevated)
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.m))
        }
    }

    // MARK: - Category

    private var categorySection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text("Категория")
                .font(AppTypography.caption)
                .foregroundStyle(AppColor.textSecondary)
            FlowLayout(spacing: AppSpacing.s) {
                ForEach(ClubCategory.allCases) { cat in
                    Button {
                        category = cat
                    } label: {
                        Label(cat.title, systemImage: "")
                            .labelStyle(.titleOnly)
                            .font(AppTypography.caption)
                            .padding(.horizontal, AppSpacing.m)
                            .padding(.vertical, AppSpacing.xs)
                            .background(category == cat ? AppColor.accent : AppColor.surface)
                            .foregroundStyle(category == cat ? AppColor.textOnAccent : AppColor.textPrimary)
                            .clipShape(Capsule())
                            .overlay(Capsule().strokeBorder(category == cat ? .clear : AppColor.divider, lineWidth: 1))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Logic

    private var canCreate: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty && !description.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func create() async {
        isCreating = true
        do {
            let ownerId = appState.currentUserID ?? MockData.currentUserID
            let club = try await appState.clubs.createClub(
                name: name.trimmingCharacters(in: .whitespaces),
                description: description.trimmingCharacters(in: .whitespaces),
                emoji: selectedEmoji,
                category: category,
                ownerId: ownerId
            )
            UIImpactFeedbackGenerator(style: .medium).impactOccurred()
            onCreated(club)
            dismiss()
        } catch {
            errorMessage = error.localizedDescription
        }
        isCreating = false
    }
}
