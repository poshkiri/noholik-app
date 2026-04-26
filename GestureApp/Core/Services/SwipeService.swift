import Foundation

struct SwipeResult: Sendable {
    let isMatch: Bool
    let matchedProfile: Profile?
}

protocol SwipeService: Sendable {
    func fetchCandidates(limit: Int) async throws -> [Profile]
    func submit(decision: SwipeDecision, for profileID: UUID) async throws -> SwipeResult
}

@MainActor
final class MockSwipeService: SwipeService {
    init() {}

    func fetchCandidates(limit: Int) async throws -> [Profile] {
        try await Task.sleep(for: .milliseconds(300))
        return MockData.sampleProfiles
    }

    func submit(decision: SwipeDecision, for profileID: UUID) async throws -> SwipeResult {
        try await Task.sleep(for: .milliseconds(150))
        let isMatch = decision != .pass && Bool.random()
        let matched = isMatch ? MockData.sampleProfiles.first(where: { $0.id == profileID }) : nil
        return SwipeResult(isMatch: isMatch, matchedProfile: matched)
    }
}
