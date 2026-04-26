import CryptoKit
import Foundation

extension UUID {
    /// Stable UUID derived from VK ID user id (so `Profile.id` stays consistent across launches).
    static func fromVKUserIDString(_ raw: String) -> UUID {
        let data = Data("vk:\(raw)".utf8)
        let digest = SHA256.hash(data: data)
        var bytes = Array(digest.prefix(16))
        bytes[6] = (bytes[6] & 0x0F) | 0x40
        bytes[8] = (bytes[8] & 0x3F) | 0x80
        return UUID(uuid: (
            bytes[0], bytes[1], bytes[2], bytes[3],
            bytes[4], bytes[5], bytes[6], bytes[7],
            bytes[8], bytes[9], bytes[10], bytes[11],
            bytes[12], bytes[13], bytes[14], bytes[15]
        ))
    }
}
