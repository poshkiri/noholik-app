import Foundation

struct Club: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var description: String
    var emoji: String
    var category: ClubCategory
    var memberCount: Int
    var isJoined: Bool
    var channels: [ClubChannel]
    var ownerId: UUID
}

// MARK: - Category

enum ClubCategory: String, CaseIterable, Codable, Identifiable {
    case deafCulture
    case signLanguage
    case hobbies
    case city
    case support
    case fun

    var id: String { rawValue }

    var title: String {
        switch self {
        case .deafCulture:  "Глухая культура"
        case .signLanguage: "Жестовый язык"
        case .hobbies:      "Хобби"
        case .city:         "Город"
        case .support:      "Поддержка"
        case .fun:          "Развлечения"
        }
    }

    var emoji: String {
        switch self {
        case .deafCulture:  "🤟"
        case .signLanguage: "👋"
        case .hobbies:      "🎯"
        case .city:         "🌆"
        case .support:      "💙"
        case .fun:          "🎉"
        }
    }
}

// MARK: - Channel

struct ClubChannel: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    var name: String
    var kind: ChannelKind
    var lastMessagePreview: String?
    var unreadCount: Int

    enum ChannelKind: String, Codable {
        case announcements
        case general
        case media
        case offtopic

        var icon: String {
            switch self {
            case .announcements: "megaphone.fill"
            case .general:       "number"
            case .media:         "photo.on.rectangle"
            case .offtopic:      "bubble.left.and.bubble.right"
            }
        }
    }
}
