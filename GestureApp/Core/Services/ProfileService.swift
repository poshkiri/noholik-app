import Foundation

protocol ProfileService: Sendable {
    func loadMyProfile(userID: UUID) async throws -> Profile?
    func saveProfile(_ profile: Profile) async throws

    /// Stores a new avatar and returns the URL that should be written
    /// into `Profile.photoURLs`. Implementations may upload the image
    /// to a backend or persist it locally.
    func uploadAvatar(_ data: Data) async throws -> URL
}

@MainActor
final class MockProfileService: ProfileService {
    private var myProfile: Profile?

    init() {}

    func loadMyProfile(userID: UUID) async throws -> Profile? {
        try await Task.sleep(for: .milliseconds(200))
        return myProfile
    }

    func saveProfile(_ profile: Profile) async throws {
        try await Task.sleep(for: .milliseconds(200))
        myProfile = profile
    }

    func uploadAvatar(_ data: Data) async throws -> URL {
        try await Task.sleep(for: .milliseconds(100))
        return try PhotoStore.saveAvatar(data)
    }
}
