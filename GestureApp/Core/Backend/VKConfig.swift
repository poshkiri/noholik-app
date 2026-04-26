import Foundation

/// Credentials from [VK ID business cabinet](https://id.vk.ru/business/go).
///
/// **Must match** `CFBundleURLSchemes` in `Info.plist`: the scheme is `vk` + `clientId`
/// (e.g. clientId `52735902` → scheme `vk52735902`).
enum VKConfig {
    private static let placeholderSecret = "REPLACE_WITH_VK_CLIENT_SECRET"

    /// Application ID from id.vk.com (must match URL scheme `vk\(clientId)` in Info.plist).
    ///
    /// Prefer setting `VKClientID` in `Info.plist` / build settings for production builds.
    static let clientId = (Bundle.main.object(forInfoDictionaryKey: "VKClientID") as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .nonEmpty ?? "54556592"

    /// VK protected key / secret.
    ///
    /// Do not commit the real value to git. Inject it through build settings and `Info.plist`
    /// with the `VKClientSecret` key for local or CI builds.
    static let clientSecret = (Bundle.main.object(forInfoDictionaryKey: "VKClientSecret") as? String)?
        .trimmingCharacters(in: .whitespacesAndNewlines)
        .nonEmpty ?? placeholderSecret

    static var hasRealSecret: Bool {
        clientSecret != placeholderSecret
    }
}

private extension String {
    var nonEmpty: String? { isEmpty ? nil : self }
}
