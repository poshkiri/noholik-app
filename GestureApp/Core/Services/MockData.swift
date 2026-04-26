import Foundation

/// Static mock data for development, previews and screenshots.
/// Remove (or gate behind DEBUG) before shipping.
nonisolated enum MockData {
    static let currentUserID = UUID(uuidString: "00000000-0000-0000-0000-000000000001")!

    static let sampleProfiles: [Profile] = [
        Profile(
            id: UUID(uuidString: "11111111-1111-1111-1111-111111111111")!,
            name: "Аня",
            birthdate: Calendar.current.date(byAdding: .year, value: -25, to: .now)!,
            gender: .female,
            city: "Москва",
            bio: "Люблю жестовые песни и кофе на рассвете. Ищу того, кто любит гулять.",
            hearingStatus: .deaf,
            communication: [.rsl, .text],
            interests: ["Кофе", "Путешествия", "Кино", "Жестовое пение"],
            photoURLs: [],
            videoIntroURL: nil,
            isVerified: true
        ),
        Profile(
            id: UUID(uuidString: "22222222-2222-2222-2222-222222222222")!,
            name: "Даша",
            birthdate: Calendar.current.date(byAdding: .year, value: -28, to: .now)!,
            gender: .female,
            city: "Санкт-Петербург",
            bio: "Слабослышащая, учусь на дизайнера. Обожаю море.",
            hearingStatus: .hardOfHearing,
            communication: [.rsl, .text, .lipReading],
            interests: ["Дизайн", "Море", "Книги"],
            photoURLs: [],
            videoIntroURL: nil,
            isVerified: false
        ),
        Profile(
            id: UUID(uuidString: "33333333-3333-3333-3333-333333333333")!,
            name: "Марк",
            birthdate: Calendar.current.date(byAdding: .year, value: -31, to: .now)!,
            gender: .male,
            city: "Казань",
            bio: "CODA, переводчик РЖЯ. Играю на гитаре, чувствую вибрации.",
            hearingStatus: .coda,
            communication: [.rsl, .speech, .text],
            interests: ["Музыка", "Гитара", "Поход"],
            photoURLs: [],
            videoIntroURL: nil,
            isVerified: true
        )
    ]

    static var sampleMatches: [Match] {
        sampleProfiles.prefix(2).enumerated().map { index, profile in
            Match(
                id: UUID(),
                profile: profile,
                createdAt: .now.addingTimeInterval(-Double(index) * 86_400),
                lastMessagePreview: index == 0 ? "Привет! 🤟" : nil,
                lastMessageAt: index == 0 ? .now.addingTimeInterval(-3600) : nil,
                hasUnread: index == 0
            )
        }
    }

    static func sampleMessages(for matchID: UUID) -> [Message] {
        let otherID = UUID()
        return [
            Message(
                id: UUID(), matchID: matchID, senderID: otherID,
                kind: .text("Привет! 🤟"),
                createdAt: .now.addingTimeInterval(-3600), isRead: true
            ),
            Message(
                id: UUID(), matchID: matchID, senderID: currentUserID,
                kind: .text("Привет! Как дела?"),
                createdAt: .now.addingTimeInterval(-3500), isRead: true
            ),
            Message(
                id: UUID(), matchID: matchID, senderID: otherID,
                kind: .text("Отлично. Видела твою видео-визитку, красиво жестишь!"),
                createdAt: .now.addingTimeInterval(-3400), isRead: true
            )
        ]
    }
}
