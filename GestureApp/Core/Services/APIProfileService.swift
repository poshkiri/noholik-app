import Foundation

/// Reads/writes profiles against the GestureApp REST API.
@MainActor
final class APIProfileService: ProfileService {

    private let client: GestureAPIClient

    init(client: GestureAPIClient) {
        self.client = client
    }

    // MARK: - ProfileService

    func loadMyProfile(userID: UUID) async throws -> Profile? {
        do {
            let dto: ProfileDTO = try await client.get(path: "/profile/me")
            return dto.toDomain()
        } catch APIError.badStatus(404, _) {
            return nil
        }
    }

    func saveProfile(_ profile: Profile) async throws {
        let dto = ProfileDTO(profile)
        let _: ProfileDTO = try await client.put(path: "/profile/me", body: dto)
    }

    // MARK: - Media uploads

    /// Uploads a JPEG photo and returns its public CDN URL.
    func uploadAvatar(_ data: Data) async throws -> URL {
        let response: MediaURLResponse = try await client.upload(
            path: "/media/avatar",
            fileData: data,
            mimeType: "image/jpeg",
            fieldName: "file"
        )
        guard let url = URL(string: response.url) else {
            throw APIError.decoding(URLError(.badURL))
        }
        return url
    }

    /// Reads a local video file and uploads it; returns its public CDN URL.
    func uploadVideoIntro(localURL: URL) async throws -> URL {
        let data = try Data(contentsOf: localURL)
        let response: MediaURLResponse = try await client.upload(
            path: "/media/video",
            fileData: data,
            mimeType: "video/mp4",
            fieldName: "file"
        )
        guard let url = URL(string: response.url) else {
            throw APIError.decoding(URLError(.badURL))
        }
        return url
    }
}

// MARK: - Private DTO

private struct MediaURLResponse: Decodable {
    let url: String
}
