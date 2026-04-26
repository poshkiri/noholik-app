@preconcurrency import AVFoundation
import Foundation

/// Low-level wrapper around `AVCaptureSession` that knows how to configure a
/// camera + mic pipeline and write a movie file to disk.
///
/// Runs all AVFoundation work on a private serial queue because the session APIs
/// aren't main-actor friendly. Callers interact via async methods and a single
/// continuation-bridged delegate.
@MainActor
final class CameraController: NSObject {

    nonisolated enum Position: Sendable { case front, back }

    nonisolated enum CameraError: Error, LocalizedError {
        case notAuthorized
        case configuration
        case noDevice

        var errorDescription: String? {
            switch self {
            case .notAuthorized: "Нет доступа к камере или микрофону"
            case .configuration: "Не удалось настроить камеру"
            case .noDevice: "Камера не найдена"
            }
        }
    }

    // MARK: Public (main actor)

    let session = AVCaptureSession()

    private(set) var position: Position = .front
    private(set) var isRecording = false

    // MARK: Private

    private let sessionQueue = DispatchQueue(label: "gestureapp.camera.session")
    private let movieOutput = AVCaptureMovieFileOutput()
    private var videoDeviceInput: AVCaptureDeviceInput?
    private var audioDeviceInput: AVCaptureDeviceInput?
    private var recordingContinuation: CheckedContinuation<URL, Error>?

    // MARK: Permissions

    static func requestAccess() async -> Bool {
        async let video = AVCaptureDevice.requestAccess(for: .video)
        async let audio = AVCaptureDevice.requestAccess(for: .audio)
        let (okV, okA) = await (video, audio)
        return okV && okA
    }

    // MARK: Session lifecycle

    func configure() async throws {
        guard AVCaptureDevice.authorizationStatus(for: .video) == .authorized,
              AVCaptureDevice.authorizationStatus(for: .audio) == .authorized
        else { throw CameraError.notAuthorized }

        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [session, movieOutput] in
                session.beginConfiguration()
                session.sessionPreset = .high

                do {
                    let videoDevice = try Self.bestCamera(for: .front)
                    let videoInput = try AVCaptureDeviceInput(device: videoDevice)
                    guard session.canAddInput(videoInput) else {
                        throw CameraError.configuration
                    }
                    session.addInput(videoInput)

                    if let audioDevice = AVCaptureDevice.default(for: .audio) {
                        let audioInput = try AVCaptureDeviceInput(device: audioDevice)
                        if session.canAddInput(audioInput) {
                            session.addInput(audioInput)
                            Task { @MainActor in self.audioDeviceInput = audioInput }
                        }
                    }

                    guard session.canAddOutput(movieOutput) else {
                        throw CameraError.configuration
                    }
                    session.addOutput(movieOutput)
                    if let connection = movieOutput.connection(with: .video),
                       connection.isVideoStabilizationSupported {
                        connection.preferredVideoStabilizationMode = .auto
                    }

                    session.commitConfiguration()
                    Task { @MainActor in self.videoDeviceInput = videoInput }
                    continuation.resume()
                } catch {
                    session.commitConfiguration()
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    func start() {
        sessionQueue.async { [session] in
            if !session.isRunning { session.startRunning() }
        }
    }

    func stop() {
        sessionQueue.async { [session] in
            if session.isRunning { session.stopRunning() }
        }
    }

    // MARK: Recording

    func startRecording() async throws -> URL {
        guard !isRecording else { throw CameraError.configuration }
        isRecording = true

        return try await withCheckedThrowingContinuation { continuation in
            self.recordingContinuation = continuation
            let url = Self.makeTempURL()
            sessionQueue.async { [movieOutput] in
                movieOutput.startRecording(to: url, recordingDelegate: self)
            }
        }
    }

    func stopRecording() {
        guard isRecording else { return }
        sessionQueue.async { [movieOutput] in
            if movieOutput.isRecording { movieOutput.stopRecording() }
        }
    }

    func flipCamera() async throws {
        let newPosition: Position = position == .front ? .back : .front
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            sessionQueue.async { [session] in
                session.beginConfiguration()
                defer { session.commitConfiguration() }
                do {
                    let oldInput = self.unsafelyReadVideoDeviceInput()
                    if let oldInput { session.removeInput(oldInput) }

                    let device = try Self.bestCamera(for: newPosition == .front ? .front : .back)
                    let newInput = try AVCaptureDeviceInput(device: device)
                    guard session.canAddInput(newInput) else {
                        if let oldInput { session.addInput(oldInput) }
                        throw CameraError.configuration
                    }
                    session.addInput(newInput)
                    Task { @MainActor in
                        self.videoDeviceInput = newInput
                        self.position = newPosition
                    }
                    continuation.resume()
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }

    // MARK: - Helpers

    /// Reads `videoDeviceInput` off the session queue — unsafe but allowed
    /// because we're inside a `beginConfiguration`/`commitConfiguration` pair.
    nonisolated private func unsafelyReadVideoDeviceInput() -> AVCaptureDeviceInput? {
        MainActor.assumeIsolated { videoDeviceInput }
    }

    nonisolated private static func bestCamera(for position: AVCaptureDevice.Position) throws -> AVCaptureDevice {
        let discovery = AVCaptureDevice.DiscoverySession(
            deviceTypes: [.builtInWideAngleCamera, .builtInDualCamera, .builtInTripleCamera],
            mediaType: .video,
            position: position
        )
        guard let device = discovery.devices.first else { throw CameraError.noDevice }
        return device
    }

    nonisolated private static func makeTempURL() -> URL {
        let filename = "intro-\(UUID().uuidString).mov"
        return FileManager.default.temporaryDirectory.appendingPathComponent(filename)
    }
}

// MARK: - AVCaptureFileOutputRecordingDelegate

extension CameraController: AVCaptureFileOutputRecordingDelegate {
    nonisolated func fileOutput(
        _ output: AVCaptureFileOutput,
        didFinishRecordingTo outputFileURL: URL,
        from connections: [AVCaptureConnection],
        error: Error?
    ) {
        Task { @MainActor in
            self.isRecording = false
            let continuation = self.recordingContinuation
            self.recordingContinuation = nil
            if let error {
                continuation?.resume(throwing: error)
            } else {
                continuation?.resume(returning: outputFileURL)
            }
        }
    }
}
