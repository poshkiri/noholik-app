import PhotosUI
import SwiftUI

struct MyProfileView: View {
    @Environment(AppState.self) private var appState

    @State private var pickerItem: PhotosPickerItem?
    @State private var isUploading = false
    @State private var errorMessage: String?
    @State private var isEditPresented = false

    var body: some View {
        NavigationStack {
            ZStack {
                AppColor.background.ignoresSafeArea()
                ScrollView {
                    if let profile = appState.myProfile {
                        content(for: profile)
                    } else {
                        ProgressView().padding(.top, AppSpacing.xxl)
                    }
                }
            }
            .navigationTitle("Профиль")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if appState.myProfile != nil {
                        Button {
                            isEditPresented = true
                        } label: {
                            Image(systemName: "pencil")
                                .foregroundStyle(AppColor.accent)
                        }
                        .accessibilityLabel("Редактировать профиль")
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    NavigationLink("Настройки") { SettingsView() }
                }
            }
            .onChange(of: pickerItem) { _, newValue in
                guard let newValue else { return }
                Task { await loadPickedPhoto(newValue) }
            }
            .sheet(isPresented: $isEditPresented) {
                if let profile = appState.myProfile {
                    EditProfileView(profile: profile).environment(appState)
                }
            }
            .alert(
                "Не удалось загрузить фото",
                isPresented: Binding(get: { errorMessage != nil }, set: { if !$0 { errorMessage = nil } }),
                presenting: errorMessage
            ) { _ in
                Button("ОК", role: .cancel) { errorMessage = nil }
            } message: { Text($0) }
        }
    }

    private func content(for profile: Profile) -> some View {
        VStack(spacing: AppSpacing.l) {
            avatar(for: profile)
            nameBlock(for: profile)
            infoCards(for: profile)
            interests(for: profile)
            Spacer(minLength: AppSpacing.xl)
        }
        .padding(AppSpacing.l)
    }

    private func avatar(for profile: Profile) -> some View {
        ZStack(alignment: .bottomTrailing) {
            AvatarImage(url: profile.primaryPhotoURL, initial: profile.name.prefix(1))
                .frame(width: 140, height: 140)
                .overlay {
                    if isUploading {
                        Circle().fill(.black.opacity(0.35))
                        ProgressView().tint(.white)
                    }
                }

            PhotosPicker(selection: $pickerItem, matching: .images, photoLibrary: .shared()) {
                Circle()
                    .fill(AppColor.surface)
                    .frame(width: 44, height: 44)
                    .overlay(Image(systemName: "camera.fill").foregroundStyle(AppColor.accent))
                    .shadow(color: .black.opacity(0.15), radius: 4, y: 2)
            }
            .disabled(isUploading)
            .accessibilityLabel("Изменить фото профиля")
        }
        .padding(.top, AppSpacing.l)
    }

    private func nameBlock(for profile: Profile) -> some View {
        VStack(spacing: AppSpacing.xxs) {
            HStack(spacing: AppSpacing.xs) {
                Text("\(profile.name), \(profile.age)")
                    .font(AppTypography.title)
                    .foregroundStyle(AppColor.textPrimary)
                if profile.isVerified {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.blue)
                }
            }
            Text(profile.city)
                .font(AppTypography.subheadline)
                .foregroundStyle(AppColor.textSecondary)
        }
    }

    private func infoCards(for profile: Profile) -> some View {
        VStack(spacing: AppSpacing.s) {
            InfoRow(icon: profile.hearingStatus.emoji, title: "Слышимость", value: profile.hearingStatus.title)
            InfoRow(icon: "💬", title: "Языки", value: profile.communication.map(\.title).joined(separator: ", "))
            if !profile.bio.isEmpty {
                InfoRow(icon: "📝", title: "О себе", value: profile.bio)
            }
        }
    }

    private func interests(for profile: Profile) -> some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            Text("Интересы")
                .font(AppTypography.headline)
                .foregroundStyle(AppColor.textPrimary)
            FlowLayout(spacing: AppSpacing.s) {
                ForEach(profile.interests, id: \.self) { Chip(title: $0) }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func loadPickedPhoto(_ item: PhotosPickerItem) async {
        isUploading = true
        defer { isUploading = false; pickerItem = nil }
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                errorMessage = "Не удалось прочитать выбранный файл."
                return
            }
            try await appState.updateMyPhoto(data)
        } catch {
            errorMessage = error.localizedDescription
        }
    }
}

// MARK: - Avatar

private struct AvatarImage: View {
    let url: URL?
    let initial: Substring

    var body: some View {
        ZStack {
            LinearGradient(colors: [AppColor.accent, AppColor.accentSoft],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            if let url {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let img): img.resizable().scaledToFill()
                    case .empty: ProgressView().tint(.white)
                    default: initialLabel
                    }
                }
            } else {
                initialLabel
            }
        }
        .clipShape(Circle())
    }

    private var initialLabel: some View {
        Text(String(initial)).font(.system(size: 56, weight: .bold)).foregroundStyle(.white)
    }
}

// MARK: - Info row

private struct InfoRow: View {
    let icon: String; let title: String; let value: String
    var body: some View {
        HStack(alignment: .top, spacing: AppSpacing.m) {
            Text(icon).font(.title2)
            VStack(alignment: .leading, spacing: 2) {
                Text(title).font(AppTypography.caption).foregroundStyle(AppColor.textSecondary)
                Text(value).font(AppTypography.body).foregroundStyle(AppColor.textPrimary)
            }
            Spacer()
        }
        .padding(AppSpacing.l)
        .background(AppColor.surface)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.m))
    }
}

// MARK: - Settings

struct SettingsView: View {
    @Environment(AppState.self) private var appState
    @State private var isDeletingAccount = false
    @State private var showDeleteConfirm = false
    @State private var deleteErrorMessage: String?

    var body: some View {
        List {
            Section("Аккаунт") {
                NavigationLink {
                    VerificationInfoView()
                } label: {
                    Label("Верификация", systemImage: "checkmark.seal")
                }

                NavigationLink {
                    SubscriptionInfoView()
                } label: {
                    Label("Подписка Premium", systemImage: "star.fill")
                }

                NavigationLink {
                    PrivacySettingsView()
                } label: {
                    Label("Приватность", systemImage: "lock.fill")
                }

                NavigationLink {
                    DataProcessingInfoView()
                } label: {
                    Label("Обработка данных", systemImage: "hand.raised.fill")
                }
            }

            Section("Поддержка") {
                NavigationLink {
                    HelpView()
                } label: {
                    Label("Помощь", systemImage: "questionmark.circle")
                }

                NavigationLink {
                    CommunityRulesView()
                } label: {
                    Label("Правила сообщества", systemImage: "doc.text")
                }
            }

            Section {
                Button(role: .destructive) {
                    Task { await appState.signOut() }
                } label: {
                    Label("Выйти", systemImage: "rectangle.portrait.and.arrow.right")
                }

                Button(role: .destructive) {
                    showDeleteConfirm = true
                } label: {
                    if isDeletingAccount {
                        Label("Удаление аккаунта...", systemImage: "trash")
                    } else {
                        Label("Удалить аккаунт", systemImage: "trash")
                    }
                }
                .disabled(isDeletingAccount)
            }
        }
        .navigationTitle("Настройки")
        .confirmationDialog(
            "Удалить аккаунт?",
            isPresented: $showDeleteConfirm,
            titleVisibility: .visible
        ) {
            Button("Удалить аккаунт", role: .destructive) {
                Task { await deleteAccount() }
            }
            Button("Отмена", role: .cancel) {}
        } message: {
            Text("Будут удалены профиль, мэтчи и сообщения. Это действие нельзя отменить.")
        }
        .alert(
            "Не удалось удалить аккаунт",
            isPresented: Binding(get: { deleteErrorMessage != nil }, set: { if !$0 { deleteErrorMessage = nil } }),
            presenting: deleteErrorMessage
        ) { _ in
            Button("ОК", role: .cancel) { deleteErrorMessage = nil }
        } message: { Text($0) }
    }

    private func deleteAccount() async {
        isDeletingAccount = true
        defer { isDeletingAccount = false }
        do {
            try await appState.deleteAccount()
        } catch {
            deleteErrorMessage = error.localizedDescription
        }
    }
}

// MARK: - Settings sub-screens

private struct VerificationInfoView: View {
    var body: some View {
        InfoScreenView(
            emoji: "✅",
            title: "Верификация профиля",
            text: "Верифицированные профили получают синюю галочку — другие пользователи видят, что ты настоящий человек.\n\nВерификация через видео-селфи будет доступна в следующем обновлении.",
            note: "Твои личные данные не передаются третьим лицам."
        )
        .navigationTitle("Верификация")
    }
}

private struct SubscriptionInfoView: View {
    var body: some View {
        InfoScreenView(
            emoji: "⭐",
            title: "GestureApp Premium",
            text: "С Premium ты получаешь:\n• Безлимитные лайки\n• Посмотреть, кто тебя лайкнул\n• Суперлайки каждый день\n• Приоритет в ленте\n• Без рекламы",
            note: "Подписка появится в ближайшем обновлении."
        )
        .navigationTitle("Premium")
    }
}

private struct PrivacySettingsView: View {
    @AppStorage("privacy_hideAge")    private var hideAge = false
    @AppStorage("privacy_hideCity")   private var hideCity = false
    @AppStorage("privacy_showOnline") private var showOnline = true
    @AppStorage("legal_acceptsPrivacyPolicy") private var acceptsPrivacyPolicy = false
    @AppStorage("legal_acceptsSensitiveData") private var acceptsSensitiveData = false

    var body: some View {
        List {
            Section("Профиль") {
                Toggle("Скрыть возраст", isOn: $hideAge)
                Toggle("Скрыть город", isOn: $hideCity)
                Toggle("Показывать статус «онлайн»", isOn: $showOnline)
            }
            Section("Согласия") {
                Toggle("Согласие на обработку персональных данных", isOn: $acceptsPrivacyPolicy)
                Toggle("Согласие на обработку данных о статусе слуха", isOn: $acceptsSensitiveData)
            }
            Section {
                Text("Перед релизом в России замените локальные переключатели на серверный журнал согласий с датой, версией документа и IP/устройством.")
                    .font(AppTypography.caption)
                    .foregroundStyle(AppColor.textSecondary)
            }
        }
        .navigationTitle("Приватность")
    }
}

private struct HelpView: View {
    private let faq: [(q: String, a: String)] = [
        ("Как работают мэтчи?", "Когда два человека ставят друг другу лайк — это мэтч. После этого открывается чат."),
        ("Как удалить аккаунт?", "Открой Настройки → Удалить аккаунт. Профиль, мэтчи и сообщения будут удалены."),
        ("Почему нет новых профилей?", "Мы показываем людей из твоего города и с похожими предпочтениями. Попробуй расширить фильтры."),
        ("Как работают суперлайки?", "Суперлайк сообщает человеку, что ты точно хочешь познакомиться. Их количество ограничено в бесплатной версии."),
        ("Мой вопрос не здесь", "Напиши на gesture.app.support@gmail.com — ответим в течение 24 часов."),
    ]

    var body: some View {
        List(faq, id: \.q) { item in
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(item.q).font(AppTypography.bodyBold).foregroundStyle(AppColor.textPrimary)
                Text(item.a).font(AppTypography.body).foregroundStyle(AppColor.textSecondary)
            }
            .padding(.vertical, AppSpacing.xs)
            .listRowBackground(AppColor.background)
        }
        .listStyle(.plain)
        .navigationTitle("Помощь")
    }
}

private struct DataProcessingInfoView: View {
    var body: some View {
        InfoScreenView(
            emoji: "🛡️",
            title: "Обработка данных",
            text: "Мы обрабатываем данные профиля, фотографии, видео, сообщения и технические данные входа для работы приложения.\n\nСтатус слуха относится к чувствительной информации, поэтому для него нужно отдельное согласие пользователя.\n\nПеред релизом в России здесь должны быть ссылки на политику, согласие, способ отзыва согласия и контакты оператора персональных данных.",
            note: "Production-версия должна хранить журнал согласий на сервере в российской инфраструктуре."
        )
        .navigationTitle("Данные")
    }
}

private struct CommunityRulesView: View {
    private let rules = [
        ("1. Уважение", "Любые оскорбления, дискриминация или буллинг запрещены. Это пространство для всех."),
        ("2. Честность", "Используй настоящие фотографии и корректную информацию о себе."),
        ("3. Безопасность", "Не передавай личные данные (адрес, паспорт, банковские данные) незнакомым людям."),
        ("4. Согласие", "Любое общение — только при взаимном желании. «Нет» — значит нет."),
        ("5. Сообщай о нарушениях", "Если видишь нарушение — жми «Пожаловаться» на профиле. Мы рассматриваем все жалобы."),
    ]

    var body: some View {
        List(rules, id: \.0) { item in
            VStack(alignment: .leading, spacing: AppSpacing.xs) {
                Text(item.0).font(AppTypography.bodyBold).foregroundStyle(AppColor.accent)
                Text(item.1).font(AppTypography.body).foregroundStyle(AppColor.textSecondary)
            }
            .padding(.vertical, AppSpacing.xs)
            .listRowBackground(AppColor.background)
        }
        .listStyle(.plain)
        .navigationTitle("Правила")
    }
}

// MARK: - Reusable info screen

private struct InfoScreenView: View {
    let emoji: String
    let title: String
    let text: String
    let note: String

    var body: some View {
        ZStack {
            AppColor.background.ignoresSafeArea()
            ScrollView {
                VStack(spacing: AppSpacing.l) {
                    Text(emoji).font(.system(size: 64)).padding(.top, AppSpacing.xl)
                    Text(title).font(AppTypography.title).foregroundStyle(AppColor.textPrimary)
                    Text(text)
                        .font(AppTypography.body)
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                    Text(note)
                        .font(AppTypography.caption)
                        .foregroundStyle(AppColor.textSecondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, AppSpacing.xl)
                }
                .padding(AppSpacing.xl)
            }
        }
    }
}

#Preview {
    MyProfileView().environment(AppState())
}
