import Foundation
import Observation

@Observable
@MainActor
final class ChatViewModel {
    var messages: [Message] = []
    var draft: String = ""
    var isSending = false

    let match: Match
    private let currentUserID: UUID
    private let service: ChatService

    init(match: Match, currentUserID: UUID, service: ChatService) {
        self.match = match
        self.currentUserID = currentUserID
        self.service = service
    }

    func load() async {
        if let fetched = try? await service.fetchMessages(matchID: match.id) {
            messages = fetched
        }
    }

    func isMine(_ message: Message) -> Bool {
        message.senderID == currentUserID
    }

    func sendText() async {
        let trimmed = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        let message = Message(
            id: UUID(),
            matchID: match.id,
            senderID: currentUserID,
            kind: .text(trimmed),
            createdAt: .now,
            isRead: false
        )
        messages.append(message)
        draft = ""

        isSending = true
        defer { isSending = false }
        try? await service.send(message)
    }

    func sendVideo(url: URL, durationSec: Double) async {
        let message = Message(
            id: UUID(),
            matchID: match.id,
            senderID: currentUserID,
            kind: .video(url: url, durationSec: durationSec, thumbnailURL: nil),
            createdAt: .now,
            isRead: false
        )
        messages.append(message)
        try? await service.send(message)
    }
}
