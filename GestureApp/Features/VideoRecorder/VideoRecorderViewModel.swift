import Foundation
import Observation

@Observable
@MainActor
final class VideoRecorderViewModel {

    enum Phase: Equatable {
        case loading
        case denied
        case ready
        case recording
        case review(url: URL, duration: TimeInterval)
        case error(String)
    }

    let maxDuration: TimeInterval = 30

    let controller = CameraController()
    private(set) var phase: Phase = .loading
    private(set) var elapsed: TimeInterval = 0

    var progress: Double {
        min(elapsed / maxDuration, 1)
    }

    private var timerTask: Task<Void, Never>?
    private var recordingStartedAt: Date?

    // MARK: Lifecycle

    func onAppear() async {
        let granted = await CameraController.requestAccess()
        guard granted else {
            phase = .denied
            return
        }
        do {
            try await controller.configure()
            controller.start()
            phase = .ready
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    func onDisappear() {
        timerTask?.cancel()
        controller.stop()
    }

    // MARK: Recording flow

    func toggleRecording() async {
        switch phase {
        case .ready:
            await startRecording()
        case .recording:
            controller.stopRecording()
        default:
            break
        }
    }

    func retake() {
        if case let .review(url, _) = phase {
            try? FileManager.default.removeItem(at: url)
        }
        elapsed = 0
        phase = .ready
    }

    func flipCamera() async {
        do {
            try await controller.flipCamera()
        } catch {
            phase = .error(error.localizedDescription)
        }
    }

    // MARK: Private

    private func startRecording() async {
        phase = .recording
        recordingStartedAt = .now
        startTimer()

        do {
            let url = try await controller.startRecording()
            let duration = recordingStartedAt.map { Date.now.timeIntervalSince($0) } ?? 0
            timerTask?.cancel()
            phase = .review(url: url, duration: min(duration, maxDuration))
        } catch {
            timerTask?.cancel()
            phase = .error(error.localizedDescription)
        }
    }

    private func startTimer() {
        timerTask?.cancel()
        timerTask = Task { @MainActor [weak self] in
            guard let self else { return }
            while !Task.isCancelled {
                try? await Task.sleep(for: .milliseconds(100))
                guard let started = self.recordingStartedAt else { return }
                self.elapsed = Date.now.timeIntervalSince(started)
                if self.elapsed >= self.maxDuration {
                    self.controller.stopRecording()
                    return
                }
            }
        }
    }
}
