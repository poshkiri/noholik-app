import Foundation

/// Preferred way to communicate. Used as a filter and as profile info.
enum CommunicationPreference: String, CaseIterable, Codable, Identifiable, Sendable {
    case rsl
    case asl
    case international
    case text
    case speech
    case lipReading

    var id: String { rawValue }

    var title: String {
        switch self {
        case .rsl: "РЖЯ"
        case .asl: "ASL"
        case .international: "Международный ЖЯ"
        case .text: "Текст"
        case .speech: "Голос"
        case .lipReading: "Чтение по губам"
        }
    }
}
