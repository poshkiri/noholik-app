import SwiftUI

struct OnboardingFlowView: View {
    @Environment(AppState.self) private var appState
    @State private var vm = OnboardingViewModel()

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()

            VStack(spacing: AppSpacing.l) {
                // Reads vm.step only → re-renders only on step change, not on text input.
                ProgressView(value: vm.step.progress)
                    .tint(AppColor.accent)
                    .padding(.horizontal, AppSpacing.xl)
                    .padding(.top, AppSpacing.s)

                ScrollView {
                    stepContent
                        .padding(.horizontal, AppSpacing.xl)
                        .padding(.vertical, AppSpacing.l)
                }
                // .immediately — клавиатура убирается при первом движении прокрутки.
                // Используем вместо .interactively чтобы избежать конфликта жестов
                // между DatePicker и ScrollView («gesture gate timed out»).
                .scrollDismissesKeyboard(.immediately)
                .scrollBounceBehavior(.basedOnSize)

                // Extracted to a separate struct so that re-renders caused
                // by canProceed (which reads vm.name / vm.city) stay isolated
                // to this footer — the ScrollView above is never rebuilt on keystrokes.
                OnboardingFooter(vm: vm, onFinish: { await finish() })
            }
        }
        .animation(.snappy, value: vm.step)
    }

    // MARK: - Step content

    @ViewBuilder
    private var stepContent: some View {
        // vm.step is read here → only this switch re-runs on step change.
        switch vm.step {
        case .welcome:   WelcomeStepView()
        case .hearing:   HearingStatusStepView(vm: vm)
        case .language:  LanguageStepView(vm: vm)
        case .basics:    BasicsStepView(vm: vm)
        case .interests: InterestsStepView(vm: vm)
        case .video:     VideoIntroStepView(vm: vm)
        case .done:      DoneStepView()
        }
    }

    private func finish() async {
        let userID = appState.currentUserID ?? MockData.currentUserID
        let profile = vm.buildProfile(userID: userID)
        await appState.didCompleteOnboarding(with: profile)
    }
}

// MARK: - Footer (isolated)

/// Isolated from the scroll content.
/// Reads vm.canProceed → re-renders when name/city/interests change,
/// but the parent's ScrollView is not affected.
private struct OnboardingFooter: View {
    @Bindable var vm: OnboardingViewModel
    let onFinish: () async -> Void

    var body: some View {
        VStack(spacing: AppSpacing.s) {
            if vm.step == .done {
                PrimaryButton(title: "Поехали") {
                    Task { await onFinish() }
                }
            } else {
                PrimaryButton(
                    title: vm.step == .video ? "Готово" : "Далее",
                    isEnabled: vm.canProceed
                ) {
                    if vm.step == .video {
                        vm.next()
                        Task { await onFinish() }
                    } else {
                        vm.next()
                    }
                }
            }
            if vm.step != .welcome && vm.step != .done {
                Button("Назад") { vm.back() }
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .padding(.horizontal, AppSpacing.xl)
        .padding(.bottom, AppSpacing.l)
    }
}

// MARK: - Step views

private struct WelcomeStepView: View {
    var body: some View {
        VStack(spacing: AppSpacing.l) {
            Text("🤟").font(.system(size: 80))
            Text("Давайте познакомимся")
                .font(AppTypography.title)
                .foregroundStyle(AppColor.textPrimary)
            Text("Мы создадим твой профиль за 2 минуты. Пожалуйста, будь собой — сообщество ценит честность.")
                .font(AppTypography.body)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, AppSpacing.xxl)
    }
}

private struct HearingStatusStepView: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            Text("Как ты себя определяешь?")
                .font(AppTypography.title2)
                .foregroundStyle(AppColor.textPrimary)
            Text("Это поможет нам и сообществу лучше понимать друг друга.")
                .font(AppTypography.subheadline)
                .foregroundStyle(AppColor.textSecondary)

            VStack(spacing: AppSpacing.s) {
                ForEach(HearingStatus.allCases) { status in
                    let isSelected = vm.hearingStatus == status
                    Button { vm.hearingStatus = status } label: {
                        HStack(spacing: AppSpacing.m) {
                            Text(status.emoji).font(.title2)
                            Text(status.title)
                                .font(AppTypography.body)
                                .foregroundStyle(AppColor.textPrimary)
                            Spacer()
                            if isSelected {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(AppColor.accent)
                            }
                        }
                        .padding(AppSpacing.l)
                        .background(AppColor.surface)
                        .overlay(
                            RoundedRectangle(cornerRadius: AppRadius.m)
                                .strokeBorder(isSelected ? AppColor.accent : AppColor.divider, lineWidth: 1.5)
                        )
                        .clipShape(RoundedRectangle(cornerRadius: AppRadius.m))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

private struct LanguageStepView: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            Text("Как ты общаешься?")
                .font(AppTypography.title2)
                .foregroundStyle(AppColor.textPrimary)
            Text("Выбери все подходящие способы — мы покажем тебе совместимых людей.")
                .font(AppTypography.subheadline)
                .foregroundStyle(AppColor.textSecondary)

            FlowLayout(spacing: AppSpacing.s) {
                ForEach(CommunicationPreference.allCases) { option in
                    Chip(title: option.title, isSelected: vm.communication.contains(option)) {
                        if vm.communication.contains(option) {
                            vm.communication.remove(option)
                        } else {
                            vm.communication.insert(option)
                        }
                    }
                }
            }
        }
    }
}

private struct BasicsStepView: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            Text("Расскажи о себе")
                .font(AppTypography.title2)
                .foregroundStyle(AppColor.textPrimary)

            AppTextField(
                title: "Имя",
                text: $vm.name,
                placeholder: "Как тебя зовут?",
                contentType: .givenName
            )

            DatePicker(
                "Дата рождения",
                selection: $vm.birthdate,
                in: ...Date.now,
                displayedComponents: .date
            )
            .datePickerStyle(.compact)
            .font(AppTypography.body)

            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text("Пол")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.textSecondary)
                Picker("Пол", selection: $vm.gender) {
                    ForEach(Gender.allCases) { Text($0.title).tag($0) }
                }
                .pickerStyle(.segmented)
            }

            AppTextField(
                title: "Город",
                text: $vm.city,
                placeholder: "Москва",
                contentType: .addressCity
            )

            BioField(text: $vm.bio)
        }
    }
}

/// Bio field extracted to keep BasicsStepView body free of axis-based TextField quirks.
private struct BioField: View {
    @Binding var text: String
    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text("О себе")
                .font(AppTypography.caption)
                .foregroundStyle(AppColor.textSecondary)
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

private struct InterestsStepView: View {
    @Bindable var vm: OnboardingViewModel

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            Text("Что тебе интересно?")
                .font(AppTypography.title2)
                .foregroundStyle(AppColor.textPrimary)
            Text("Выбери минимум 3 интереса.")
                .font(AppTypography.subheadline)
                .foregroundStyle(AppColor.textSecondary)

            FlowLayout(spacing: AppSpacing.s) {
                ForEach(OnboardingViewModel.interestPool, id: \.self) { tag in
                    Chip(title: tag, isSelected: vm.interests.contains(tag)) {
                        if vm.interests.contains(tag) {
                            vm.interests.remove(tag)
                        } else {
                            vm.interests.insert(tag)
                        }
                    }
                }
            }
        }
    }
}

private struct VideoIntroStepView: View {
    @Bindable var vm: OnboardingViewModel
    @State private var isRecorderPresented = false

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.l) {
            Text("Видео-визитка")
                .font(AppTypography.title2)
                .foregroundStyle(AppColor.textPrimary)
            Text("Запиши короткое видео (до 30 сек), где ты представишься на жестовом языке или голосом. Это главное, что увидят люди.")
                .font(AppTypography.subheadline)
                .foregroundStyle(AppColor.textSecondary)

            Button { isRecorderPresented = true } label: {
                VStack(spacing: AppSpacing.m) {
                    Image(systemName: vm.videoIntroURL == nil ? "video.badge.plus" : "checkmark.seal.fill")
                        .font(.system(size: 48))
                        .foregroundStyle(AppColor.accent)
                    Text(vm.videoIntroURL == nil ? "Записать видео" : "Видео записано")
                        .font(AppTypography.bodyBold)
                        .foregroundStyle(AppColor.textPrimary)
                    Text(vm.videoIntroURL == nil
                         ? "Шаг можно пропустить, но с видео профиль заметнее."
                         : "Нажми, чтобы перезаписать")
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, AppSpacing.xxl)
                .background(AppColor.surface)
                .overlay(
                    RoundedRectangle(cornerRadius: AppRadius.l)
                        .strokeBorder(AppColor.divider, style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                )
                .clipShape(RoundedRectangle(cornerRadius: AppRadius.l))
            }
            .buttonStyle(.plain)
        }
        .fullScreenCover(isPresented: $isRecorderPresented) {
            VideoRecorderView { url in
                if let url { vm.videoIntroURL = url }
            }
        }
    }
}

private struct DoneStepView: View {
    var body: some View {
        VStack(spacing: AppSpacing.l) {
            Text("🎉").font(.system(size: 80))
            Text("Всё готово!")
                .font(AppTypography.title)
                .foregroundStyle(AppColor.textPrimary)
            Text("Сохраняем профиль и открываем ленту.")
                .font(AppTypography.body)
                .foregroundStyle(AppColor.textSecondary)
                .multilineTextAlignment(.center)
        }
        .padding(.top, AppSpacing.xxl)
    }
}

#Preview {
    OnboardingFlowView().environment(AppState())
}
