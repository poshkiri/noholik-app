import Foundation
import UIKit
import VKID
import VKIDCore

/// VK ID OAuth via official SDK (`VKID.shared.authorize`).
@MainActor
final class VKAuthService: AuthService {

    func signInWithVK(presenter: UIViewController) async throws -> UUID {
        guard VKIDBootstrap.isConfigured else { throw GestureAuthError.vkNotConfigured }

        return try await withCheckedThrowingContinuation { (cont: CheckedContinuation<UUID, Error>) in
            VKID.shared.authorize(
                with: AuthConfiguration(),
                oAuthProvider: .vkid,
                using: .uiViewController(presenter)
            ) { (result: AuthResult) in
                switch result {
                case .success(let session):
                    let raw = String(describing: session.userId)
                    cont.resume(returning: UUID.fromVKUserIDString(raw))
                case .failure(let err):
                    if case AuthError.cancelled = err {
                        cont.resume(throwing: GestureAuthError.cancelled)
                    } else {
                        cont.resume(throwing: GestureAuthError.unknown)
                    }
                }
            }
        }
    }

    func signInWithApple() async throws -> UUID {
        throw GestureAuthError.unknown
    }

    func signOut() async throws {
        guard VKIDBootstrap.isConfigured else { return }
        let sessions = VKID.shared.authorizedSessions
        guard !sessions.isEmpty else { return }
        await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
            let group = DispatchGroup()
            for session in sessions {
                group.enter()
                session.logout { _ in group.leave() }
            }
            group.notify(queue: .main) { cont.resume() }
        }
    }

    /// Restores app user id when VK SDK still has a saved session.
    func restoreSession() -> UUID? {
        guard VKIDBootstrap.isConfigured else { return nil }
        guard let session = VKID.shared.currentAuthorizedSession else { return nil }
        let raw = String(describing: session.userId)
        return UUID.fromVKUserIDString(raw)
    }
}
