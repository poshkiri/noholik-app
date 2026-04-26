import Foundation

/// Central place for backend API settings.
///
/// Change `baseURL` once your server is deployed.
/// For local testing start the backend locally and use `http://localhost:3000/api/v1`.
enum APIConfig {
    /// Base URL of the GestureApp REST API.
    /// **Must not** have a trailing slash.
    static let baseURL = URL(string: "https://backend-two-nu-39.vercel.app/api/v1")!

    /// `false` until you replace `YOUR-DOMAIN` with a real host (then network calls run).
    /// Note: URL normalises the host to lowercase, so comparison must be case-insensitive.
    static var isConfigured: Bool {
        guard let host = baseURL.host else { return false }
        return !host.lowercased().contains("your-domain")
    }
}
