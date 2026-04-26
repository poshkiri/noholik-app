import Foundation

struct MatchDTO: Decodable, Sendable {
    let id: UUID
    let userA: UUID
    let userB: UUID
    let createdAt: Date

    enum CodingKeys: String, CodingKey {
        case id
        case userA = "user_a"
        case userB = "user_b"
        case createdAt = "created_at"
    }

    /// Returns the id of the other participant (the one that's not me).
    func otherParticipantID(currentUserID: UUID) -> UUID {
        userA == currentUserID ? userB : userA
    }
}

struct SwipeInsertDTO: Encodable, Sendable {
    let swiperId: UUID
    let targetId: UUID
    let decision: String

    enum CodingKeys: String, CodingKey {
        case swiperId = "swiper_id"
        case targetId = "target_id"
        case decision
    }
}
