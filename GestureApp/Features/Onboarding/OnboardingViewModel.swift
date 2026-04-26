import Foundation
import Observation

@Observable
@MainActor
final class OnboardingViewModel {
    enum Step: Int, CaseIterable {
        case welcome, hearing, language, basics, interests, video, done

        var progress: Double {
            Double(rawValue) / Double(Step.allCases.count - 1)
        }
    }

    var step: Step = .welcome
    var name: String = ""
    var birthdate: Date = Calendar.current.date(byAdding: .year, value: -25, to: .now) ?? .now
    var gender: Gender = .female
    var city: String = ""
    var bio: String = ""
    var hearingStatus: HearingStatus?
    var communication: Set<CommunicationPreference> = []
    var interests: Set<String> = []
    var videoIntroURL: URL?

    static let interestPool: [String] = [
        "Кофе", "Путешествия", "Кино", "Книги", "Спорт", "Музыка",
        "Жестовое пение", "Фотография", "Настолки", "Готовка", "Поход",
        "Искусство", "Танцы", "Игры", "Мода", "Наука"
    ]

    var canProceed: Bool {
        switch step {
        case .welcome: true
        case .hearing: hearingStatus != nil
        case .language: !communication.isEmpty
        case .basics: !name.trimmingCharacters(in: .whitespaces).isEmpty && !city.trimmingCharacters(in: .whitespaces).isEmpty
        case .interests: interests.count >= 3
        case .video: true
        case .done: true
        }
    }

    func next() {
        guard let next = Step(rawValue: step.rawValue + 1) else { return }
        step = next
    }

    func back() {
        guard let prev = Step(rawValue: step.rawValue - 1) else { return }
        step = prev
    }

    func buildProfile(userID: UUID) -> Profile {
        Profile(
            id: userID,
            name: name,
            birthdate: birthdate,
            gender: gender,
            city: city,
            bio: bio,
            hearingStatus: hearingStatus ?? .deaf,
            communication: Array(communication),
            interests: Array(interests),
            photoURLs: [],
            videoIntroURL: videoIntroURL,
            isVerified: false
        )
    }
}
