import Foundation

/// Swipe feed and decision submission against the GestureApp REST API.
@MainActor
final class APISwipeService: SwipeService {

    private let client: GestureAPIClient

    init(client: GestureAPIClient) {
        self.client = client
    }

    // MARK: - SwipeService

    func fetchCandidates(limit: Int) async throws -> [Profile] {
        let dtos: [ProfileDTO] = try await client.get(path: "/feed?limit=\(limit)")
        // Path uses query string intentionally; GestureAPIClient builds URL via string concatenation.
        return dtos.map { $0.toDomain() }
    }

    func submit(decision: SwipeDecision, for profileID: UUID) async throws -> SwipeResult {
        let body = SwipeBody(targetId: profileID, liked: decision != .pass)
        let response: SwipeResponse = try await client.post(path: "/swipes", body: body)

        let matchedProfile: Profile? = response.match.flatMap { match in
            // The match DTO only contains IDs; profile data is fetched separately if needed.
            // For now we return nil and let the Matches screen reload.
            _ = match
            return nil
        }

        return SwipeResult(isMatch: response.matched, matchedProfile: matchedProfile)
    }
}

// MARK: - Request / Response DTOs

private struct SwipeBody: Encodable {
    let targetId: UUID
    let liked: Bool

    enum CodingKeys: String, CodingKey {
        case targetId = "target_id"
        case liked
    }
}

private struct SwipeResponse: Decodable {
    let matched: Bool
    let match: MatchDTO?
}
