import Foundation

/// Bridges between Swift camelCase enum cases and Postgres snake_case DB enums.

extension Gender {
    var dbValue: String {
        switch self {
        case .female: "female"
        case .male: "male"
        case .nonBinary: "non_binary"
        case .other: "other"
        }
    }

    nonisolated init?(dbValue: String) {
        switch dbValue {
        case "female": self = .female
        case "male": self = .male
        case "non_binary": self = .nonBinary
        case "other": self = .other
        default: return nil
        }
    }
}

extension HearingStatus {
    var dbValue: String {
        switch self {
        case .deaf: "deaf"
        case .hardOfHearing: "hard_of_hearing"
        case .lateDeafened: "late_deafened"
        case .coda: "coda"
        case .hearingAlly: "hearing_ally"
        }
    }

    nonisolated init?(dbValue: String) {
        switch dbValue {
        case "deaf": self = .deaf
        case "hard_of_hearing": self = .hardOfHearing
        case "late_deafened": self = .lateDeafened
        case "coda": self = .coda
        case "hearing_ally": self = .hearingAlly
        default: return nil
        }
    }
}

extension CommunicationPreference {
    var dbValue: String {
        switch self {
        case .rsl: "rsl"
        case .asl: "asl"
        case .international: "international"
        case .text: "text"
        case .speech: "speech"
        case .lipReading: "lip_reading"
        }
    }

    nonisolated init?(dbValue: String) {
        switch dbValue {
        case "rsl": self = .rsl
        case "asl": self = .asl
        case "international": self = .international
        case "text": self = .text
        case "speech": self = .speech
        case "lip_reading": self = .lipReading
        default: return nil
        }
    }
}

extension SwipeDecision {
    var dbValue: String {
        switch self {
        case .like: "like"
        case .pass: "pass"
        case .superLike: "super_like"
        }
    }
}

enum MessageKindDB: String, Codable, Sendable {
    case text, video, image
}
