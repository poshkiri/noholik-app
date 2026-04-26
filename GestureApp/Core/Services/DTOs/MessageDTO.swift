import Foundation

struct MessageDTO: Codable, Sendable {
    let id: UUID
    let matchId: UUID
    let senderId: UUID
    let kind: String
    let text: String?
    let mediaUrl: String?
    let durationSec: Double?
    let thumbnailUrl: String?
    let createdAt: Date
    let readAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case matchId = "match_id"
        case senderId = "sender_id"
        case kind, text
        case mediaUrl = "media_url"
        case durationSec = "duration_sec"
        case thumbnailUrl = "thumbnail_url"
        case createdAt = "created_at"
        case readAt = "read_at"
    }

    nonisolated func toDomain() -> Message? {
        guard let kindDB = MessageKindDB(rawValue: kind) else { return nil }
        let domainKind: Message.Kind
        switch kindDB {
        case .text:
            domainKind = .text(text ?? "")
        case .video:
            guard let url = mediaUrl.flatMap(URL.init(string:)) else { return nil }
            let thumb = thumbnailUrl.flatMap(URL.init(string:))
            domainKind = .video(url: url, durationSec: durationSec ?? 0, thumbnailURL: thumb)
        case .image:
            guard let url = mediaUrl.flatMap(URL.init(string:)) else { return nil }
            domainKind = .image(url: url)
        }
        return Message(
            id: id,
            matchID: matchId,
            senderID: senderId,
            kind: domainKind,
            createdAt: createdAt,
            isRead: readAt != nil
        )
    }
}

/// Insert payload — `id`, `created_at`, `read_at` are managed by the DB.
struct MessageInsertDTO: Encodable, Sendable {
    let matchId: UUID
    let senderId: UUID
    let kind: String
    let text: String?
    let mediaUrl: String?
    let durationSec: Double?
    let thumbnailUrl: String?

    enum CodingKeys: String, CodingKey {
        case matchId = "match_id"
        case senderId = "sender_id"
        case kind, text
        case mediaUrl = "media_url"
        case durationSec = "duration_sec"
        case thumbnailUrl = "thumbnail_url"
    }

    init(_ message: Message) {
        self.matchId = message.matchID
        self.senderId = message.senderID
        switch message.kind {
        case .text(let t):
            self.kind = MessageKindDB.text.rawValue
            self.text = t
            self.mediaUrl = nil
            self.durationSec = nil
            self.thumbnailUrl = nil
        case .video(let url, let dur, let thumb):
            self.kind = MessageKindDB.video.rawValue
            self.text = nil
            self.mediaUrl = url.absoluteString
            self.durationSec = dur
            self.thumbnailUrl = thumb?.absoluteString
        case .image(let url):
            self.kind = MessageKindDB.image.rawValue
            self.text = nil
            self.mediaUrl = url.absoluteString
            self.durationSec = nil
            self.thumbnailUrl = nil
        }
    }
}
