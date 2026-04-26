import Foundation

/// Matches and chat messages against the GestureApp REST API.
@MainActor
final class APIChatService: ChatService {

    private let client: GestureAPIClient

    init(client: GestureAPIClient) {
        self.client = client
    }

    // MARK: - ChatService

    /// The backend returns each match with the other participant's profile embedded
    /// so we can build the `Match` domain object in a single round-trip.
    func fetchMatches() async throws -> [Match] {
        let dtos: [MatchEnrichedDTO] = try await client.get(path: "/matches")
        return dtos.map { dto in
            Match(
                id: dto.id,
                profile: dto.otherProfile.toDomain(),
                createdAt: dto.createdAt,
                lastMessagePreview: dto.lastMessagePreview,
                lastMessageAt: dto.lastMessageAt,
                hasUnread: dto.hasUnread ?? false
            )
        }
    }

    func fetchMessages(matchID: UUID) async throws -> [Message] {
        let dtos: [MessageDTO] = try await client.get(path: "/matches/\(matchID)/messages")
        return dtos.compactMap { $0.toDomain() }
    }

    func send(_ message: Message) async throws {
        let body = MessageInsertDTO(message)
        let _: MessageDTO = try await client.post(
            path: "/matches/\(message.matchID)/messages",
            body: body
        )
    }
}

// MARK: - Enriched Match DTO

/// The `/matches` endpoint returns each row joined with the other participant's profile.
private struct MatchEnrichedDTO: Decodable {
    let id: UUID
    let createdAt: Date
    let otherProfile: ProfileDTO
    let lastMessagePreview: String?
    let lastMessageAt: Date?
    let hasUnread: Bool?

    enum CodingKeys: String, CodingKey {
        case id
        case createdAt          = "created_at"
        case otherProfile       = "other_profile"
        case lastMessagePreview = "last_message_preview"
        case lastMessageAt      = "last_message_at"
        case hasUnread          = "has_unread"
    }
}
