import Foundation

struct Profile: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var birthdate: Date
    var gender: Gender
    var city: String
    var bio: String
    var hearingStatus: HearingStatus
    var communication: [CommunicationPreference]
    var interests: [String]
    var photoURLs: [URL]
    var videoIntroURL: URL?
    var isVerified: Bool

    var age: Int {
        Calendar.current.dateComponents([.year], from: birthdate, to: .now).year ?? 0
    }

    var primaryPhotoURL: URL? { photoURLs.first }
}
