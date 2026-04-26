import Foundation
import Observation

/// Top-level app state. Owns services and high-level session/onboarding status.
///
/// Lives for the whole app lifetime and is injected via `.environment(...)`.
/// Using `@Observable` (iOS 17+) so every SwiftUI view that reads a property
/// re-renders automatically when it changes.
@Observable
@MainActor
final class AppState {

    enum Phase: Equatable {
        case splash
        case signedOut
        case onboarding
        case signedIn
    }

    // MARK: Session

    private(set) var phase: Phase = .splash
    private(set) var currentUserID: UUID?
    private(set) var myProfile: Profile?

    private var didRunBootstrap = false

    // MARK: Services

    let auth: AuthService
    let profiles: ProfileService
    let swipe: SwipeService
    let chat: ChatService
    let clubs: ClubService
    let presence = PresenceStore()

    init(
        auth: AuthService,
        profiles: ProfileService,
        swipe: SwipeService,
        chat: ChatService,
        clubs: ClubService
    ) {
        self.auth = auth
        self.profiles = profiles
        self.swipe = swipe
        self.chat = chat
        self.clubs = clubs
    }

    /// Mock wiring used by SwiftUI previews and snapshot tests.
    convenience init() {
        self.init(
            auth: MockAuthService(),
            profiles: MockProfileService(),
            swipe: MockSwipeService(),
            chat: MockChatService(),
            clubs: MockClubService()
        )
    }

    /// Production wiring: VK ID + GestureApp REST API.
    static func live() -> AppState {
        let client = GestureAPIClient.shared
        let authService = APIAuthService(client: client)
        let chatService = APIChatService(client: client)

        // When the backend returns 401, try to get a fresh JWT silently before signing out.
        client.tokenRefreshHandler = { await authService.silentRefreshJWT() }

        return AppState(
            auth: authService,
            profiles: APIProfileService(client: client),
            swipe: APISwipeService(client: client),
            chat: chatService,
            clubs: MockClubService()   // TODO: replace with APIClubService when backend is ready
        )
    }

    // MARK: Lifecycle

    func bootstrap() async {
        guard !didRunBootstrap else { return }
        didRunBootstrap = true

        // Configure SDK synchronously before any async work.
        VKIDBootstrap.configureIfNeeded()
        presence.seedMock(for: MockData.sampleProfiles)

        // Safety valve: if SDK init hangs, never stay on a blank splash forever.
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(4))
            if phase == .splash { phase = .signedOut }
        }

        if let userID = auth.restoreSession() {
            currentUserID = userID
            await loadProfileAfterRestore(for: userID)
            return
        }
        phase = .signedOut
    }

    /// Called from SignInView after a successful VK OAuth flow.
    /// The user just authenticated — NEVER send them back to sign-in on error.
    func didSignIn(userID: UUID) async {
        currentUserID = userID

        guard APIConfig.isConfigured else {
            myProfile = nil
            phase = .onboarding
            return
        }

        // Try to load the profile. Any failure (network, 401, 500, timeout)
        // → go to onboarding so the user can start filling their profile.
        let loaded = try? await profiles.loadMyProfile(userID: userID)
        myProfile = loaded
        phase = (loaded == nil) ? .onboarding : .signedIn
    }

    func didCompleteOnboarding(with profile: Profile) async {
        try? await profiles.saveProfile(profile)
        myProfile = profile
        phase = .signedIn
    }

    // MARK: - Profile mutations

    func updateMyProfile(_ updated: Profile) async {
        myProfile = updated
        if APIConfig.isConfigured {
            try? await profiles.saveProfile(updated)
        }
    }

    // MARK: Profile photo

    /// Saves a newly-picked avatar and updates `myProfile.photoURLs`.
    ///
    /// Uses the configured backend when available; otherwise persists the
    /// image locally via `PhotoStore` so it survives app restarts.
    func updateMyPhoto(_ data: Data) async throws {
        guard var profile = myProfile else { return }

        let url: URL
        if APIConfig.isConfigured {
            url = try await profiles.uploadAvatar(data)
        } else {
            url = try PhotoStore.saveAvatar(data)
        }

        var photos = profile.photoURLs
        photos.insert(url, at: 0)
        if photos.count > 6 { photos = Array(photos.prefix(6)) }
        profile.photoURLs = photos

        if APIConfig.isConfigured {
            try? await profiles.saveProfile(profile)
        }
        myProfile = profile
    }

    func signOut() async {
        try? await auth.signOut()
        currentUserID = nil
        myProfile = nil
        phase = .signedOut
    }

    func deleteAccount() async throws {
        try await auth.deleteAccount()
        currentUserID = nil
        myProfile = nil
        phase = .signedOut
    }

    // MARK: Private

    /// Called at app launch when a previous JWT exists in Keychain.
    /// On 401 we know the token is truly stale → sign out.
    /// On any other error we show onboarding (don't throw the user back to sign-in
    /// just because the network hiccupped on launch).
    private func loadProfileAfterRestore(for userID: UUID) async {
        guard APIConfig.isConfigured else {
            myProfile = nil
            phase = .onboarding
            return
        }
        do {
            let loaded = try await profiles.loadMyProfile(userID: userID)
            myProfile = loaded
            phase = (loaded == nil) ? .onboarding : .signedIn
        } catch APIError.unauthorized {
            try? await auth.signOut()
            currentUserID = nil
            myProfile = nil
            phase = .signedOut
        } catch {
            myProfile = nil
            phase = .onboarding
        }
    }
}
