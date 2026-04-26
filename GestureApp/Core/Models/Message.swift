import Foundation

struct Message: Identifiable, Hashable, Sendable {
    enum Kind: Hashable, Sendable {
        case text(String)
        case video(url: URL, durationSec: Double, thumbnailURL: URL?)
        case image(url: URL)
    }

    let id: UUID
    let matchID: UUID
    let senderID: UUID
    let kind: Kind
    let createdAt: Date
    var isRead: Bool
}
