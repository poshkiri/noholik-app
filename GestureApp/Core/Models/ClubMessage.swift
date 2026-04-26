import Foundation

struct ClubMessage: Identifiable, Codable, Sendable {
    let id: UUID
    let authorId: UUID
    let authorName: String
    let text: String
    let createdAt: Date
    /// emoji → count of users who reacted
    var reactions: [String: Int]
}
