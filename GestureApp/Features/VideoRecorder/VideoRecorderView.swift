import AVKit
import SwiftUI

/// Full-screen camera UI.
/// Calls `onFinish` with the recorded video URL (or nil if cancelled).
struct VideoRecorderView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var vm = VideoRecorderViewModel()

    let onFinish: (URL?) -> Void

    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()

            switch vm.phase {
            case .loading:
                ProgressView().tint(.white)
            case .denied:
                deniedView
            case .error(let message):
                errorView(message: message)
            case .ready, .recording:
                recordingInterface
            case .review(let url, let duration):
                ReviewView(url: url, duration: duration,
                           onRetake: { vm.retake() },
                           onAccept: { onFinish(url); dismiss() })
            }
        }
        .statusBarHidden()
        .task { await vm.onAppear() }
        .onDisappear { vm.onDisappear() }
    }

    // MARK: Recording UI

    private var recordingInterface: some View {
        ZStack {
            CameraPreviewView(session: vm.controller.session)
                .ignoresSafeArea()

            VStack {
                topBar
                Spacer()
                hint
                controls
            }
            .padding(AppSpacing.l)
        }
    }

    private var topBar: some View {
        HStack {
            Button {
                onFinish(nil); dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.title2.weight(.semibold))
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }

            Spacer()

            if case .recording = vm.phase {
                HStack(spacing: AppSpacing.s) {
                    Circle().fill(.red).frame(width: 8, height: 8)
                    Text(timerText)
                        .font(AppTypography.bodyBold.monospacedDigit())
                }
                .padding(.horizontal, AppSpacing.m)
                .padding(.vertical, AppSpacing.s)
                .background(.ultraThinMaterial, in: Capsule())
            }

            Spacer()

            Button { Task { await vm.flipCamera() } } label: {
                Image(systemName: "arrow.triangle.2.circlepath.camera.fill")
                    .font(.title2)
                    .frame(width: 40, height: 40)
                    .background(.ultraThinMaterial, in: Circle())
            }
            .disabled(vm.phase == .recording)
            .opacity(vm.phase == .recording ? 0.3 : 1)
        }
        .foregroundStyle(.white)
    }

    private var hint: some View {
        Text("Представься на жестовом языке. До 30 сек.")
            .font(AppTypography.subheadline)
            .foregroundStyle(.white)
            .padding(.horizontal, AppSpacing.m)
            .padding(.vertical, AppSpacing.s)
            .background(.black.opacity(0.35), in: Capsule())
            .padding(.bottom, AppSpacing.l)
    }

    private var controls: some View {
        ZStack {
            Circle()
                .stroke(.white.opacity(0.35), lineWidth: 4)
                .frame(width: 92, height: 92)

            if case .recording = vm.phase {
                Circle()
                    .trim(from: 0, to: vm.progress)
                    .stroke(AppColor.accent, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                    .frame(width: 92, height: 92)
                    .rotationEffect(.degrees(-90))
                    .animation(.linear(duration: 0.1), value: vm.progress)
            }

            Button { Task { await vm.toggleRecording() } } label: {
                let isRecording = vm.phase == .recording
                RoundedRectangle(cornerRadius: isRecording ? 8 : 36)
                    .fill(AppColor.accent)
                    .frame(width: isRecording ? 36 : 72,
                           height: isRecording ? 36 : 72)
                    .animation(.spring(response: 0.3, dampingFraction: 0.7), value: isRecording)
            }
        }
        .padding(.bottom, AppSpacing.xl)
    }

    private var timerText: String {
        let seconds = Int(vm.elapsed)
        let ms = Int((vm.elapsed - Double(seconds)) * 10)
        return String(format: "%d.%d сек", seconds, ms)
    }

    // MARK: Denied / Error

    private var deniedView: some View {
        VStack(spacing: AppSpacing.l) {
            Image(systemName: "video.slash.fill")
                .font(.system(size: 48))
                .foregroundStyle(.white.opacity(0.7))
            Text("Нет доступа к камере")
                .font(AppTypography.title2)
                .foregroundStyle(.white)
            Text("Разреши доступ к камере и микрофону в Настройках → GestureApp.")
                .font(AppTypography.subheadline)
                .foregroundStyle(.white.opacity(0.7))
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)

            VStack(spacing: AppSpacing.s) {
                PrimaryButton(title: "Открыть настройки") {
                    if let url = URL(string: UIApplication.openSettingsURLString) {
                        UIApplication.shared.open(url)
                    }
                }
                PrimaryButton(title: "Назад", style: .ghost) {
                    onFinish(nil); dismiss()
                }
            }
            .padding(.horizontal, AppSpacing.xl)
        }
    }

    private func errorView(message: String) -> some View {
        VStack(spacing: AppSpacing.l) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundStyle(AppColor.warning)
            Text(message)
                .font(AppTypography.body)
                .foregroundStyle(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, AppSpacing.xl)
            PrimaryButton(title: "Закрыть", style: .ghost) {
                onFinish(nil); dismiss()
            }
            .padding(.horizontal, AppSpacing.xl)
        }
    }
}

// MARK: - Review (accept / retake)

private struct ReviewView: View {
    let url: URL
    let duration: TimeInterval
    let onRetake: () -> Void
    let onAccept: () -> Void

    @State private var player: AVPlayer?

    var body: some View {
        VStack(spacing: AppSpacing.l) {
            Spacer(minLength: AppSpacing.xxl)

            if let player {
                VideoPlayer(player: player)
                    .aspectRatio(9/16, contentMode: .fit)
                    .clipShape(RoundedRectangle(cornerRadius: AppRadius.l))
                    .padding(.horizontal, AppSpacing.xl)
                    .onAppear { player.play() }
                    .onDisappear { player.pause() }
            }

            Text("Длительность: \(Int(duration)) сек")
                .font(AppTypography.subheadline)
                .foregroundStyle(.white.opacity(0.7))

            Spacer()

            VStack(spacing: AppSpacing.s) {
                PrimaryButton(title: "Использовать это видео") { onAccept() }
                PrimaryButton(title: "Перезаписать", style: .ghost, action: onRetake)
            }
            .padding(.horizontal, AppSpacing.xl)
            .padding(.bottom, AppSpacing.l)
        }
        .onAppear {
            let newPlayer = AVPlayer(url: url)
            newPlayer.actionAtItemEnd = .none
            NotificationCenter.default.addObserver(
                forName: .AVPlayerItemDidPlayToEndTime,
                object: newPlayer.currentItem,
                queue: .main
            ) { _ in
                newPlayer.seek(to: .zero)
                newPlayer.play()
            }
            self.player = newPlayer
        }
    }
}
