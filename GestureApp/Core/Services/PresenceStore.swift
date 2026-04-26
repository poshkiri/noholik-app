import Foundation
import Observation

/// Lightweight real-time presence layer.
///
/// In production this would subscribe to a WebSocket/SSE endpoint.
/// In the current mock-only mode it seeds fixed states once at launch
/// and uses a timer to make a few users randomly flip between online and
/// "was online recently" — so the UI feels alive on-device.
@Observable
@MainActor
final class PresenceStore {

    private var states: [UUID: State] = [:]

    // MARK: - Public API

    func isOnline(_ id: UUID) -> Bool { states[id]?.isOnline ?? false }

    /// Gender-aware status text: "Онлайн" / "Был 5 мин назад" / "Была 1 ч назад".
    func statusText(for profile: Profile) -> String {
        guard let s = states[profile.id] else { return "" }
        if s.isOnline { return "Онлайн" }
        guard let date = s.lastSeenAt else { return "" }
        let female = profile.gender == .female
        let interval = Date.now.timeIntervalSince(date)
        switch interval {
        case ..<60:
            return female ? "Была только что" : "Был только что"
        case 60..<3_600:
            let m = Int(interval / 60)
            return female ? "Была \(m) мин назад" : "Был \(m) мин назад"
        case 3_600..<86_400:
            let h = Int(interval / 3_600)
            return female ? "Была \(h) ч назад" : "Был \(h) ч назад"
        default:
            return female ? "Была давно" : "Был давно"
        }
    }

    // MARK: - Mock seed

    /// Seed fixed mock presence for known profile IDs and start a light
    /// timer to make the UI feel dynamic.
    func seedMock(for profiles: [Profile]) {
        // Assign a spread of statuses across profiles.
        let templates: [State] = [
            State(isOnline: true, lastSeenAt: nil),
            State(isOnline: false, lastSeenAt: Date(timeIntervalSinceNow: -4 * 60)),
            State(isOnline: false, lastSeenAt: Date(timeIntervalSinceNow: -47 * 60)),
            State(isOnline: true, lastSeenAt: nil),
            State(isOnline: false, lastSeenAt: Date(timeIntervalSinceNow: -2 * 3_600)),
        ]
        for (i, profile) in profiles.enumerated() {
            states[profile.id] = templates[i % templates.count]
        }
        startFlicker(ids: profiles.map(\.id))
    }

    // MARK: - Private

    private struct State {
        var isOnline: Bool
        var lastSeenAt: Date?
    }

    /// Periodically flickers a random profile between online ↔ "just now"
    /// to make the presence indicator feel live.
    private func startFlicker(ids: [UUID]) {
        guard !ids.isEmpty else { return }
        Task { [weak self] in
            while true {
                try? await Task.sleep(for: .seconds(Double.random(in: 20...45)))
                guard let self else { return }
                let id = ids.randomElement()!
                let current = self.states[id]?.isOnline ?? false
                self.states[id] = State(
                    isOnline: !current,
                    lastSeenAt: current ? .now : nil
                )
            }
        }
    }
}
