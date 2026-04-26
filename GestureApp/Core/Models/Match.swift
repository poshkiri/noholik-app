import Foundation

struct Match: Identifiable, Hashable, Sendable {
    let id: UUID
    let profile: Profile
    let createdAt: Date
    var lastMessagePreview: String?
    var lastMessageAt: Date?
    var hasUnread: Bool
}
