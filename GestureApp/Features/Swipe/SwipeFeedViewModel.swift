import Foundation
import Observation

@Observable
@MainActor
final class SwipeFeedViewModel {
    enum Status { case idle, loading, empty, error(String) }

    var status: Status = .idle
    var candidates: [Profile] = []
    var matchedProfile: Profile?

    private let service: SwipeService

    init(service: SwipeService) {
        self.service = service
    }

    func loadIfNeeded() async {
        guard case .idle = status, candidates.isEmpty else { return }
        await reload()
    }

    func reload() async {
        status = .loading
        do {
            let result: [Profile]
            if APIConfig.isConfigured {
                result = try await service.fetchCandidates(limit: 20)
            } else {
                // Backend not deployed yet — use mock data for UI testing.
                try? await Task.sleep(for: .milliseconds(300))
                result = MockData.sampleProfiles
            }
            candidates = result
            status = result.isEmpty ? .empty : .idle
        } catch {
            status = .error(error.localizedDescription)
        }
    }

    func swipe(_ decision: SwipeDecision, on profile: Profile) async {
        candidates.removeAll { $0.id == profile.id }
        if candidates.isEmpty { status = .empty }

        do {
            let result = try await service.submit(decision: decision, for: profile.id)
            if result.isMatch, let matched = result.matchedProfile {
                matchedProfile = matched
            }
        } catch {
            // Swallow for UX; a production version would queue and retry.
        }
    }

    func dismissMatch() {
        matchedProfile = nil
    }
}
