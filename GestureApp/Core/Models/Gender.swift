import Foundation

enum Gender: String, CaseIterable, Codable, Identifiable, Sendable {
    case female, male, nonBinary, other

    var id: String { rawValue }

    var title: String {
        switch self {
        case .female: "Женщина"
        case .male: "Мужчина"
        case .nonBinary: "Небинарный/ая"
        case .other: "Другое"
        }
    }
}
