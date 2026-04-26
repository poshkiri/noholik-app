import Foundation

/// Row-level representation of the `public.profiles` table.
///
/// Lives in its own layer so the domain `Profile` model stays clean of
/// Postgres-specific types (string enums, array columns, nullable URLs).
struct ProfileDTO: Codable, Sendable {
    let id: UUID
    var name: String
    var birthdate: Date
    var gender: String
    var city: String
    var bio: String
    var hearingStatus: String
    var communication: [String]
    var interests: [String]
    var photoUrls: [String]
    var videoIntroUrl: String?
    var isVerified: Bool
    var isHidden: Bool?

    enum CodingKeys: String, CodingKey {
        case id, name, birthdate, gender, city, bio
        case hearingStatus = "hearing_status"
        case communication, interests
        case photoUrls = "photo_urls"
        case videoIntroUrl = "video_intro_url"
        case isVerified = "is_verified"
        case isHidden = "is_hidden"
    }

    static let birthdateFormatter: DateFormatter = {
        let f = DateFormatter()
        f.calendar = Calendar(identifier: .gregorian)
        f.locale = Locale(identifier: "en_US_POSIX")
        f.timeZone = TimeZone(secondsFromGMT: 0)
        f.dateFormat = "yyyy-MM-dd"
        return f
    }()

    init(
        id: UUID,
        name: String,
        birthdate: Date,
        gender: String,
        city: String,
        bio: String,
        hearingStatus: String,
        communication: [String],
        interests: [String],
        photoUrls: [String],
        videoIntroUrl: String?,
        isVerified: Bool,
        isHidden: Bool? = nil
    ) {
        self.id = id
        self.name = name
        self.birthdate = birthdate
        self.gender = gender
        self.city = city
        self.bio = bio
        self.hearingStatus = hearingStatus
        self.communication = communication
        self.interests = interests
        self.photoUrls = photoUrls
        self.videoIntroUrl = videoIntroUrl
        self.isVerified = isVerified
        self.isHidden = isHidden
    }

    init(from decoder: any Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decode(UUID.self, forKey: .id)
        name = try c.decode(String.self, forKey: .name)
        let bStr = try c.decode(String.self, forKey: .birthdate)
        guard let date = Self.birthdateFormatter.date(from: bStr) else {
            throw DecodingError.dataCorruptedError(
                forKey: .birthdate, in: c,
                debugDescription: "Invalid birthdate: \(bStr)"
            )
        }
        birthdate = date
        gender = try c.decode(String.self, forKey: .gender)
        city = try c.decode(String.self, forKey: .city)
        bio = try c.decodeIfPresent(String.self, forKey: .bio) ?? ""
        hearingStatus = try c.decode(String.self, forKey: .hearingStatus)
        communication = try c.decodeIfPresent([String].self, forKey: .communication) ?? []
        interests = try c.decodeIfPresent([String].self, forKey: .interests) ?? []
        photoUrls = try c.decodeIfPresent([String].self, forKey: .photoUrls) ?? []
        videoIntroUrl = try c.decodeIfPresent(String.self, forKey: .videoIntroUrl)
        isVerified = try c.decodeIfPresent(Bool.self, forKey: .isVerified) ?? false
        isHidden = try c.decodeIfPresent(Bool.self, forKey: .isHidden)
    }

    func encode(to encoder: any Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(Self.birthdateFormatter.string(from: birthdate), forKey: .birthdate)
        try c.encode(gender, forKey: .gender)
        try c.encode(city, forKey: .city)
        try c.encode(bio, forKey: .bio)
        try c.encode(hearingStatus, forKey: .hearingStatus)
        try c.encode(communication, forKey: .communication)
        try c.encode(interests, forKey: .interests)
        try c.encode(photoUrls, forKey: .photoUrls)
        try c.encodeIfPresent(videoIntroUrl, forKey: .videoIntroUrl)
        try c.encode(isVerified, forKey: .isVerified)
        try c.encodeIfPresent(isHidden, forKey: .isHidden)
    }
}

// MARK: - Mapping

extension ProfileDTO {
    init(_ profile: Profile) {
        self.init(
            id: profile.id,
            name: profile.name,
            birthdate: profile.birthdate,
            gender: profile.gender.dbValue,
            city: profile.city,
            bio: profile.bio,
            hearingStatus: profile.hearingStatus.dbValue,
            communication: profile.communication.map(\.dbValue),
            interests: profile.interests,
            photoUrls: profile.photoURLs.map(\.absoluteString),
            videoIntroUrl: profile.videoIntroURL?.absoluteString,
            isVerified: profile.isVerified
        )
    }

    nonisolated func toDomain() -> Profile {
        Profile(
            id: id,
            name: name,
            birthdate: birthdate,
            gender: Gender(dbValue: gender) ?? .other,
            city: city,
            bio: bio,
            hearingStatus: HearingStatus(dbValue: hearingStatus) ?? .hardOfHearing,
            communication: communication.compactMap(CommunicationPreference.init(dbValue:)),
            interests: interests,
            photoURLs: photoUrls.compactMap(URL.init(string:)),
            videoIntroURL: videoIntroUrl.flatMap(URL.init(string:)),
            isVerified: isVerified
        )
    }
}
