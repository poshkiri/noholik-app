import SwiftUI

struct EditProfileView: View {
    @Environment(AppState.self) private var appState
    @Environment(\.dismiss) private var dismiss

    // Local draft — only written to AppState on Save.
    @State private var name: String
    @State private var city: String
    @State private var bio: String
    @State private var birthdate: Date
    @State private var gender: Gender
    @State private var hearingStatus: HearingStatus
    @State private var communication: Set<CommunicationPreference>
    @State private var interests: Set<String>
    @State private var isSaving = false

    init(profile: Profile) {
        _name         = State(initialValue: profile.name)
        _city         = State(initialValue: profile.city)
        _bio          = State(initialValue: profile.bio)
        _birthdate    = State(initialValue: profile.birthdate)
        _gender       = State(initialValue: profile.gender)
        _hearingStatus = State(initialValue: profile.hearingStatus)
        _communication = State(initialValue: Set(profile.communication))
        _interests    = State(initialValue: Set(profile.interests))
    }

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()
                ScrollView {
                    VStack(alignment: .leading, spacing: AppSpacing.xl) {
                        basicSection
                        hearingSection
                        communicationSection
                        interestsSection
                    }
                    .padding(AppSpacing.l)
                }
                .scrollDismissesKeyboard(.interactively)
            }
            .navigationTitle("Редактировать")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Отмена") { dismiss() }
                        .foregroundStyle(AppColor.textSecondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await save() }
                    } label: {
                        if isSaving {
                            ProgressView().scaleEffect(0.8)
                        } else {
                            Text("Сохранить").fontWeight(.semibold)
                        }
                    }
                    .disabled(!canSave || isSaving)
                    .foregroundStyle(canSave ? AppColor.accent : AppColor.textSecondary)
                }
            }
        }
    }

    // MARK: - Sections

    private var basicSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            sectionHeader("Основное")

            AppTextField(title: "Имя", text: $name, placeholder: "Как тебя зовут?", contentType: .givenName)

            AppTextField(title: "Город", text: $city, placeholder: "Москва", contentType: .addressCity)

            DatePicker("Дата рождения", selection: $birthdate, in: ...Date.now, displayedComponents: .date)
                .font(AppTypography.body)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Пол").font(AppTypography.caption).foregroundStyle(AppColor.textSecondary)
                Picker("Пол", selection: $gender) {
                    ForEach(Gender.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            BioEditField(text: $bio)
        }
    }

    private var hearingSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            sectionHeader("Слышимость")

            VStack(spacing: AppSpacing.s) {
                ForEach(HearingStatus.allCases) { status in
                    let selected = hearingStatus == status
                    Button { hearingStatus = status } label: {
                        HStack(spacing: AppSpacing.m) {
                            Text(status.emoji).font(.title3)
                            Text(status.title).font(AppTypography.body).foregroundStyle(AppColor.textPrimary)
                            Spacer()
                            if selected {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(AppColor.accent)
                            }
                        }
                        .padding(AppSpacing.m)
                        .background(AppColor.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.m)
                                .strokeBorder(selected ? AppColor.accent : AppColor.divider, lineWidth: 1.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.m))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var communicationSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            sectionHeader("Способы общения")

            FlowLayout(spacing: AppSpacing.s) {
                ForEach(CommunicationPreference.allCases) { pref in
                    Chip(title: pref.title, isSelected: communication.contains(pref)) {
                        if communication.contains(pref) { communication.remove(pref) }
                        else { communication.insert(pref) }
                    }
                }
            }
        }
    }

    private var interestsSection: some View {
        VStack(alignment: .leading, spacing: AppSpacing.m) {
            sectionHeader("Интересы")

            FlowLayout(spacing: AppSpacing.s) {
                ForEach(OnboardingViewModel.interestPool, id: \.self) { tag in
                    Chip(title: tag, isSelected: interests.contains(tag)) {
                        if interests.contains(tag) { interests.remove(tag) }
                        else { interests.insert(tag) }
                    }
                }
            }
        }
    }

    private func sectionHeader(_ title: String) -> some View {
        Text(title)
            .font(AppTypography.headline)
            .foregroundStyle(AppColor.textPrimary)
    }

    // MARK: - Logic

    private var canSave: Bool {
        !name.trimmingCharacters(in: .whitespaces).isEmpty &&
        !city.trimmingCharacters(in: .whitespaces).isEmpty
    }

    private func save() async {
        guard var profile = appState.myProfile else { return }
        isSaving = true
        profile.name         = name.trimmingCharacters(in: .whitespaces)
        profile.city         = city.trimmingCharacters(in: .whitespaces)
        profile.bio          = bio.trimmingCharacters(in: .whitespaces)
        profile.birthdate    = birthdate
        profile.gender       = gender
        profile.hearingStatus = hearingStatus
        profile.communication = Array(communication)
        profile.interests    = Array(interests)
        await appState.updateMyProfile(profile)
        isSaving = false
        dismiss()
    }
}

// MARK: - Bio field (isolated to keep focus state stable)

private struct BioEditField: View {
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("О себе").font(AppTypography.caption).foregroundStyle(AppColor.textSecondary)
            TextField("Пара строк про тебя", text: $text, axis: .vertical)
                .lineLimit(3...6)
                .focused($focused)
                .font(AppTypography.body)
                .foregroundStyle(AppColor.textPrimary)
                .padding(.horizontal, AppSpacing.l)
                .padding(.vertical, AppSpacing.m)
                .background(AppColor.surfaceElevated)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.m)
                        .strokeBorder(focused ? AppColor.accent : AppColor.divider, lineWidth: 1)
                )
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.m))
        }
    }
}
