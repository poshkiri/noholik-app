import Foundation
import VKID

enum VKIDBootstrap {
    /// Call once at launch before any `VKID.shared.authorize` / session use.
    static func configureIfNeeded() {
        guard isConfigured else { return }
        let creds = AppCredentials(
            clientId: VKConfig.clientId,
            clientSecret: VKConfig.clientSecret
        )
        let config = Configuration(
            appCredentials: creds,
            loggingEnabled: false
        )
        try? VKID.shared.set(config: config)
    }

    static var isConfigured: Bool {
        VKConfig.hasRealSecret
            && VKConfig.clientId != "0"
    }
}
