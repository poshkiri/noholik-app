import Foundation

import UIKit

/// Authentication error that surfaces to UI layer (not to be confused with `VKID.AuthError`).
enum GestureAuthError: Error, LocalizedError {
    case vkNotConfigured
    case cancelled
    case network
    case unknown

    var errorDescription: String? {
        switch self {
        case .vkNotConfigured:
            "Вставьте защищённый ключ приложения в VKConfig.clientSecret (id.vk.com → GestureApp → Авторизация). Схема в Info.plist: vk + ID приложения."
        case .cancelled: "Вход отменён"
        case .network: "Нет соединения"
        case .unknown: "Что-то пошло не так"
        }
    }
}

/// Abstract auth gateway. Production: **VK ID + backend JWT**; previews: `MockAuthService`.
protocol AuthService: Sendable {
    /// Primary sign-in for the RU market (VK ID SDK).
    func signInWithVK(presenter: UIViewController) async throws -> UUID
    func signInWithApple() async throws -> UUID
    func signOut() async throws
    func deleteAccount() async throws
    /// Restores a previous session without prompting the user.
    /// Returns the `UUID` if a valid session exists, `nil` otherwise.
    func restoreSession() -> UUID?
}

extension AuthService {
    func restoreSession() -> UUID? { nil }
}

/// In-memory implementation used during development and in previews.
@MainActor
final class MockAuthService: AuthService {
    init() {}

    func signInWithVK(presenter: UIViewController) async throws -> UUID {
        try await Task.sleep(for: .milliseconds(400))
        return UUID()
    }

    func signInWithApple() async throws -> UUID {
        try await Task.sleep(for: .milliseconds(400))
        return UUID()
    }

    func signOut() async throws {}
    func deleteAccount() async throws {}
}
