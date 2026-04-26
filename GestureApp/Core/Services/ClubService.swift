import Foundation

protocol ClubService: Sendable {
    func fetchAllClubs() async throws -> [Club]
    func fetchMyClubs() async throws -> [Club]
    func join(clubId: UUID) async throws -> Club
    func leave(clubId: UUID) async throws
    func fetchMessages(channelId: UUID) async throws -> [ClubMessage]
    func send(text: String, channelId: UUID, authorId: UUID, authorName: String) async throws -> ClubMessage
    func react(emoji: String, messageId: UUID, channelId: UUID) async throws
    func createClub(name: String, description: String, emoji: String, category: ClubCategory, ownerId: UUID) async throws -> Club
}

// MARK: - Mock

@MainActor
final class MockClubService: ClubService {

    private var clubs: [Club] = MockClubs.all
    private var messages: [UUID: [ClubMessage]] = MockClubs.seedMessages()

    func fetchAllClubs() async throws -> [Club] {
        try? await Task.sleep(for: .milliseconds(200))
        return clubs
    }

    func fetchMyClubs() async throws -> [Club] {
        try? await Task.sleep(for: .milliseconds(150))
        return clubs.filter(\.isJoined)
    }

    func join(clubId: UUID) async throws -> Club {
        try? await Task.sleep(for: .milliseconds(100))
        guard let idx = clubs.firstIndex(where: { $0.id == clubId }) else {
            throw URLError(.badServerResponse)
        }
        clubs[idx].isJoined = true
        clubs[idx].memberCount += 1
        return clubs[idx]
    }

    func leave(clubId: UUID) async throws {
        try? await Task.sleep(for: .milliseconds(100))
        guard let idx = clubs.firstIndex(where: { $0.id == clubId }) else { return }
        clubs[idx].isJoined = false
        clubs[idx].memberCount -= 1
    }

    func fetchMessages(channelId: UUID) async throws -> [ClubMessage] {
        try? await Task.sleep(for: .milliseconds(180))
        return messages[channelId] ?? []
    }

    func send(text: String, channelId: UUID, authorId: UUID, authorName: String) async throws -> ClubMessage {
        let message = ClubMessage(
            id: UUID(),
            authorId: authorId,
            authorName: authorName,
            text: text,
            createdAt: .now,
            reactions: [:]
        )
        messages[channelId, default: []].append(message)
        return message
    }

    func react(emoji: String, messageId: UUID, channelId: UUID) async throws {
        guard var list = messages[channelId],
              let idx = list.firstIndex(where: { $0.id == messageId }) else { return }
        list[idx].reactions[emoji, default: 0] += 1
        messages[channelId] = list
    }

    func createClub(name: String, description: String, emoji: String, category: ClubCategory, ownerId: UUID) async throws -> Club {
        let channel = ClubChannel(
            id: UUID(),
            name: "общий",
            kind: .general,
            lastMessagePreview: nil,
            unreadCount: 0
        )
        let club = Club(
            id: UUID(),
            name: name,
            description: description,
            emoji: emoji,
            category: category,
            memberCount: 1,
            isJoined: true,
            channels: [channel],
            ownerId: ownerId
        )
        clubs.insert(club, at: 0)
        return club
    }
}

// MARK: - Seed data

private enum MockClubs {
    static let all: [Club] = [
        Club(
            id: UUID(uuidString: "A0000001-0000-0000-0000-000000000001")!,
            name: "Глухие в Москве",
            description: "Встречи, события и новости глухого и слабослышащего сообщества Москвы.",
            emoji: "🏙️",
            category: .city,
            memberCount: 412,
            isJoined: true,
            channels: [
                ClubChannel(id: UUID(uuidString: "C0000001-0000-0000-0000-000000000001")!, name: "объявления", kind: .announcements, lastMessagePreview: "В субботу встреча в кафе «Немой звук»", unreadCount: 2),
                ClubChannel(id: UUID(uuidString: "C0000001-0000-0000-0000-000000000002")!, name: "общий", kind: .general, lastMessagePreview: "Кто идёт на выставку?", unreadCount: 5),
                ClubChannel(id: UUID(uuidString: "C0000001-0000-0000-0000-000000000003")!, name: "фото", kind: .media, lastMessagePreview: nil, unreadCount: 0),
            ],
            ownerId: UUID()
        ),
        Club(
            id: UUID(uuidString: "A0000002-0000-0000-0000-000000000001")!,
            name: "РЖЯ с нуля",
            description: "Учим русский жестовый язык вместе: уроки, лайфхаки, видео-практики.",
            emoji: "👋",
            category: .signLanguage,
            memberCount: 893,
            isJoined: false,
            channels: [
                ClubChannel(id: UUID(uuidString: "C0000002-0000-0000-0000-000000000001")!, name: "объявления", kind: .announcements, lastMessagePreview: "Новый урок: числа 1–100", unreadCount: 0),
                ClubChannel(id: UUID(uuidString: "C0000002-0000-0000-0000-000000000002")!, name: "общий", kind: .general, lastMessagePreview: "Кто помнит жест «завтра»?", unreadCount: 0),
                ClubChannel(id: UUID(uuidString: "C0000002-0000-0000-0000-000000000003")!, name: "видео-практика", kind: .media, lastMessagePreview: nil, unreadCount: 0),
            ],
            ownerId: UUID()
        ),
        Club(
            id: UUID(uuidString: "A0000003-0000-0000-0000-000000000001")!,
            name: "Кино с субтитрами",
            description: "Обсуждаем фильмы и сериалы — только с хорошими субтитрами!",
            emoji: "🎬",
            category: .hobbies,
            memberCount: 236,
            isJoined: true,
            channels: [
                ClubChannel(id: UUID(uuidString: "C0000003-0000-0000-0000-000000000002")!, name: "общий", kind: .general, lastMessagePreview: "«Звук металла» — шедевр", unreadCount: 1),
                ClubChannel(id: UUID(uuidString: "C0000003-0000-0000-0000-000000000003")!, name: "постеры и кадры", kind: .media, lastMessagePreview: nil, unreadCount: 0),
            ],
            ownerId: UUID()
        ),
        Club(
            id: UUID(uuidString: "A0000004-0000-0000-0000-000000000001")!,
            name: "Поддержка и советы",
            description: "Безопасное пространство: делимся опытом, получаем поддержку от своих.",
            emoji: "💙",
            category: .support,
            memberCount: 154,
            isJoined: false,
            channels: [
                ClubChannel(id: UUID(uuidString: "C0000004-0000-0000-0000-000000000002")!, name: "общий", kind: .general, lastMessagePreview: "Как объяснить на работе…", unreadCount: 0),
                ClubChannel(id: UUID(uuidString: "C0000004-0000-0000-0000-000000000004")!, name: "оффтоп", kind: .offtopic, lastMessagePreview: nil, unreadCount: 0),
            ],
            ownerId: UUID()
        ),
        Club(
            id: UUID(uuidString: "A0000005-0000-0000-0000-000000000001")!,
            name: "Жестовое пение",
            description: "Видео, разборы и репетиции жестового пения — для сцены и для души.",
            emoji: "🎤",
            category: .deafCulture,
            memberCount: 341,
            isJoined: false,
            channels: [
                ClubChannel(id: UUID(uuidString: "C0000005-0000-0000-0000-000000000001")!, name: "объявления", kind: .announcements, lastMessagePreview: "Конкурс 15 мая!", unreadCount: 0),
                ClubChannel(id: UUID(uuidString: "C0000005-0000-0000-0000-000000000002")!, name: "общий", kind: .general, lastMessagePreview: "Кто делает разбор «Небо»?", unreadCount: 0),
            ],
            ownerId: UUID()
        ),
        Club(
            id: UUID(uuidString: "A0000006-0000-0000-0000-000000000001")!,
            name: "Игры и веселье",
            description: "Мемы, квизы, онлайн-игры — просто отдыхаем вместе.",
            emoji: "🎮",
            category: .fun,
            memberCount: 528,
            isJoined: false,
            channels: [
                ClubChannel(id: UUID(uuidString: "C0000006-0000-0000-0000-000000000002")!, name: "общий", kind: .general, lastMessagePreview: "Кто сегодня в Among Us?", unreadCount: 0),
                ClubChannel(id: UUID(uuidString: "C0000006-0000-0000-0000-000000000004")!, name: "мемы", kind: .offtopic, lastMessagePreview: nil, unreadCount: 0),
            ],
            ownerId: UUID()
        ),
    ]

    static func seedMessages() -> [UUID: [ClubMessage]] {
        let botId = UUID()
        let c1 = UUID(uuidString: "C0000001-0000-0000-0000-000000000002")!
        let c3 = UUID(uuidString: "C0000003-0000-0000-0000-000000000002")!
        return [
            c1: [
                ClubMessage(id: UUID(), authorId: botId, authorName: "Алёна", text: "Всем привет! 🤟 Кто идёт на встречу в субботу?", createdAt: Date(timeIntervalSinceNow: -3600), reactions: ["🤟": 5, "❤️": 2]),
                ClubMessage(id: UUID(), authorId: UUID(), authorName: "Дима", text: "Я иду! Во сколько и где?", createdAt: Date(timeIntervalSinceNow: -3000), reactions: [:]),
                ClubMessage(id: UUID(), authorId: botId, authorName: "Алёна", text: "В 15:00 у кафе «Немой звук» на Чистых прудах", createdAt: Date(timeIntervalSinceNow: -2800), reactions: ["👍": 3]),
            ],
            c3: [
                ClubMessage(id: UUID(), authorId: UUID(), authorName: "Маша", text: "Только посмотрела «Звук металла» — это шедевр! Такое погружение в мир глухих 😭", createdAt: Date(timeIntervalSinceNow: -7200), reactions: ["❤️": 8, "🎬": 3]),
                ClubMessage(id: UUID(), authorId: UUID(), authorName: "Костя", text: "Согласен! Главный актёр учил РЖЯ специально для роли", createdAt: Date(timeIntervalSinceNow: -6500), reactions: ["😮": 4]),
            ],
        ]
    }
}
