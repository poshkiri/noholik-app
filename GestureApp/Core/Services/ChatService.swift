import Foundation

protocol ChatService: Sendable {
    func fetchMatches() async throws -> [Match]
    func fetchMessages(matchID: UUID) async throws -> [Message]
    func send(_ message: Message) async throws
}

@MainActor
final class MockChatService: ChatService {
    private var store: [UUID: [Message]] = [:]
    private var matches: [Match] = MockData.sampleMatches

    init() {}

    func fetchMatches() async throws -> [Match] {
        try await Task.sleep(for: .milliseconds(200))
        return matches
    }

    func fetchMessages(matchID: UUID) async throws -> [Message] {
        try await Task.sleep(for: .milliseconds(200))
        if let existing = store[matchID] { return existing }
        let seed = MockData.sampleMessages(for: matchID)
        store[matchID] = seed
        return seed
    }

    func send(_ message: Message) async throws {
        try await Task.sleep(for: .milliseconds(80))
        store[message.matchID, default: []].append(message)
    }
}
