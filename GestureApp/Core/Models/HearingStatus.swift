import Foundation

/// Self-identified hearing status. Required for matching and filters.
enum HearingStatus: String, CaseIterable, Codable, Identifiable, Sendable {
    case deaf
    case hardOfHearing
    case lateDeafened
    case coda
    case hearingAlly

    var id: String { rawValue }

    var title: String {
        switch self {
        case .deaf: "Глухой/глухая"
        case .hardOfHearing: "Слабослышащий/ая"
        case .lateDeafened: "Поздно оглохший/ая"
        case .coda: "CODA (ребёнок глухих родителей)"
        case .hearingAlly: "Слышащий/ая — учу ЖЯ"
        }
    }

    var emoji: String {
        switch self {
        case .deaf: "🤟"
        case .hardOfHearing: "👂"
        case .lateDeafened: "🕊️"
        case .coda: "👨‍👩‍👧"
        case .hearingAlly: "🤝"
        }
    }
}
