import Foundation
import Observation
import UIKit

@Observable
@MainActor
final class SignInViewModel {
    var isSigningInVK = false
    var isSigningInApple = false
    var errorMessage: String?

    private let auth: AuthService
    private let onSignedIn: (UUID) async -> Void

    init(auth: AuthService, onSignedIn: @escaping (UUID) async -> Void) {
        self.auth = auth
        self.onSignedIn = onSignedIn
    }

    func signInWithVK(presenter: UIViewController?) async {
        errorMessage = nil
        guard let presenter else {
            errorMessage = GestureAuthError.unknown.errorDescription
            return
        }
        isSigningInVK = true
        defer { isSigningInVK = false }
        do {
            let userID = try await auth.signInWithVK(presenter: presenter)
            await onSignedIn(userID)
        } catch {
            errorMessage = (error as? GestureAuthError)?.errorDescription ?? error.localizedDescription
        }
    }

    func signInWithApple() async {
        errorMessage = nil
        isSigningInApple = true
        defer { isSigningInApple = false }
        do {
            let userID = try await auth.signInWithApple()
            await onSignedIn(userID)
        } catch {
            errorMessage = (error as? GestureAuthError)?.errorDescription ?? error.localizedDescription
        }
    }
}
