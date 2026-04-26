import Foundation
import UIKit
import VKID
import CryptoKit

/// Production `AuthService` implementation.
///
/// Flow:
/// 1. OAuth via VK ID SDK  →  obtain `AccessToken.value`
/// 2. `POST /auth/vk`      →  exchange for a long-lived backend JWT
/// 3. Store JWT in Keychain so subsequent API calls are authorised
/// 4. Derive stable `UUID` from the VK user id (same algorithm as Node.js backend)
@MainActor
final class APIAuthService: AuthService {

    private let client: GestureAPIClient

    init(client: GestureAPIClient) {
        self.client = client
    }

    var hasStoredToken: Bool { client.keychain.token != nil }

    // MARK: - AuthService

    func signInWithVK(presenter: UIViewController) async throws -> UUID {
        guard VKIDBootstrap.isConfigured else { throw GestureAuthError.vkNotConfigured }

        // 1. VK OAuth — always runs
        let (vkToken, vkUserIdRaw) = try await vkAuthorize(presenter: presenter)

        // 2. Exchange for backend JWT (only when the backend is configured)
        if APIConfig.isConfigured {
            do {
                let response: AuthTokenResponse = try await client.post(
                    path: "/auth/vk",
                    body: VKAuthBody(accessToken: vkToken, vkUserId: vkUserIdRaw)
                )
                client.keychain.save(response.token)
                return UUID.fromVKUserIDString(String(response.vkUserId))
            } catch {
                // Backend unreachable — proceed with local UUID so user is not stuck.
            }
        }

        // Fallback: derive UUID locally from VK user id (used until backend is deployed)
        return UUID.fromVKUserIDString(vkUserIdRaw)
    }

    func signInWithApple() async throws -> UUID {
        throw GestureAuthError.unknown
    }

    func signOut() async throws {
        client.keychain.delete()
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

    func deleteAccount() async throws {
        if APIConfig.isConfigured {
            try await client.send("DELETE", path: "/profile/me")
        }
        try await signOut()
    }

    /// Silently obtains a fresh backend JWT using the current VK ID session.
    ///
    /// Returns `true` when a new JWT was successfully saved to Keychain.
    /// Never throws — designed to be called as a fallback inside `GestureAPIClient`.
    func silentRefreshJWT() async -> Bool {
        guard VKIDBootstrap.isConfigured,
              let vkSession = VKID.shared.currentAuthorizedSession,
              APIConfig.isConfigured else { return false }

        let vkToken  = vkSession.accessToken.value
        let vkUserId = String(describing: vkSession.userId)
        do {
            let req = try client.buildPublicRequest("POST", path: "/auth/vk",
                                                    body: VKAuthBody(accessToken: vkToken,
                                                                     vkUserId: vkUserId))
            let response: AuthTokenResponse = try await client.executeDirectly(req)
            client.keychain.save(response.token)
            return true
        } catch {
            return false
        }
    }

    /// Restores a previous session without prompting the user.
    ///
    /// Returns a UUID if a valid JWT is stored in Keychain.
    /// The token signature is NOT re-verified locally; the server will reject it
    /// on the first authorised request if it has expired.
    func restoreSession() -> UUID? {
        guard let jwt = client.keychain.token else { return nil }
        guard let vkUserId = decodeVKUserID(from: jwt) else {
            client.keychain.delete()
            return nil
        }
        return UUID.fromVKUserIDString(String(vkUserId))
    }

    // MARK: - Private

    /// Returns `(accessToken, vkUserIdString)`.
    private func vkAuthorize(presenter: UIViewController) async throws -> (String, String) {
        try await withCheckedThrowingContinuation { cont in
            VKID.shared.authorize(
                with: AuthConfiguration(),
                oAuthProvider: .vkid,
                using: .uiViewController(presenter)
            ) { (result: AuthResult) in
                switch result {
                case .success(let session):
                    let userIdStr = String(describing: session.userId)
                    cont.resume(returning: (session.accessToken.value, userIdStr))
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

    /// Decodes the JWT payload (without signature verification) to extract `sub`.
    ///
    /// The backend embeds `"sub": "<vk_user_id>"` in the JWT payload.
    private func decodeVKUserID(from jwt: String) -> Int? {
        let parts = jwt.split(separator: ".")
        guard parts.count == 3 else { return nil }
        var base64 = String(parts[1])
        // Pad to a multiple of 4
        let remainder = base64.count % 4
        if remainder != 0 { base64 += String(repeating: "=", count: 4 - remainder) }
        guard let data = Data(base64Encoded: base64),
              let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let sub = json["sub"] as? String,
              let id = Int(sub)
        else { return nil }
        return id
    }
}

// MARK: - Request / Response DTOs (private to this file)

private struct VKAuthBody: Encodable {
    let accessToken: String
    let vkUserId: String

    enum CodingKeys: String, CodingKey {
        case accessToken = "access_token"
        case vkUserId    = "vk_user_id"
    }
}

private struct AuthTokenResponse: Decodable {
    let token: String
    let vkUserId: Int

    enum CodingKeys: String, CodingKey {
        case token
        case vkUserId = "vk_user_id"
    }
}
