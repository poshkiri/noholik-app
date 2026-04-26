import SwiftUI
import UIKit

/// Draggable profile card used in the swipe feed.
/// The card itself doesn't know *how* the swipe is handled — that's the parent's job.
struct ProfileCardView: View {
    let profile: Profile
    var onSwipe: (SwipeDecision) -> Void

    @State private var offset: CGSize = .zero
    @State private var isGone = false

    private let swipeThreshold: CGFloat = 120

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            background
            stampOverlay
            infoPanel
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .clipShape(RoundedRectangle(cornerRadius: AppRadius.xl))
        // Reduced from 20 → 10: shadow blur is very expensive during motion.
        .shadow(color: .black.opacity(0.10), radius: 10, y: 6)
        .offset(offset)
        .rotationEffect(.degrees(Double(offset.width / 20)), anchor: .bottom)
        .opacity(isGone ? 0 : 1)
        .gesture(drag)
        // No global .animation here — explicit withAnimation below keeps
        // drag tracking instant while snap-back and fly-out stay smooth.
    }

    // MARK: - Gesture

    private var drag: some Gesture {
        DragGesture()
            // Follow the finger with zero latency — no animation during drag.
            .onChanged { offset = $0.translation }
            .onEnded { value in
                let w = value.translation.width
                let h = value.translation.height
                if w > swipeThreshold {
                    fly(to: CGSize(width: 1000, height: h), decision: .like)
                } else if w < -swipeThreshold {
                    fly(to: CGSize(width: -1000, height: h), decision: .pass)
                } else if h < -swipeThreshold * 1.4 {
                    fly(to: CGSize(width: 0, height: -1200), decision: .superLike)
                } else {
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.8)) {
                        offset = .zero
                    }
                }
            }
    }

    private func fly(to target: CGSize, decision: SwipeDecision) {
        let style: UIImpactFeedbackGenerator.FeedbackStyle = decision == .superLike ? .heavy : .medium
        UIImpactFeedbackGenerator(style: style).impactOccurred()
        withAnimation(.easeOut(duration: 0.25)) {
            offset = target
            isGone = true
        }
        Task { @MainActor in
            try? await Task.sleep(for: .milliseconds(260))
            onSwipe(decision)
        }
    }

    // MARK: - Subviews

    private var background: some View {
        LinearGradient(
            colors: [AppColor.accent.opacity(0.7), AppColor.accentSoft],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
        .overlay(
            Image(systemName: "person.fill")
                .resizable()
                .scaledToFit()
                .foregroundStyle(.white.opacity(0.18))
                .padding(60)
        )
    }

    /// Stamp overlay — no GeometryReader; opacity clamped to [0, 1].
    private var stampOverlay: some View {
        HStack(alignment: .top) {
            stamp(text: "НРАВИТСЯ", color: .green, rotation: -12)
                .opacity(max(0, min(1, Double(offset.width / 100))))
            Spacer()
            stamp(text: "НЕТ", color: .red, rotation: 12)
                .opacity(max(0, min(1, Double(-offset.width / 100))))
        }
        .padding(AppSpacing.l)
    }

    private func stamp(text: String, color: Color, rotation: Double) -> some View {
        Text(text)
            .font(.system(.largeTitle, design: .rounded, weight: .heavy))
            .foregroundStyle(color)
            .padding(.horizontal, AppSpacing.m)
            .padding(.vertical, AppSpacing.xs)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.s)
                    .strokeBorder(color, lineWidth: 4)
            )
            .rotationEffect(.degrees(rotation))
    }

    private var infoPanel: some View {
        VStack(alignment: .leading, spacing: AppSpacing.s) {
            HStack(spacing: AppSpacing.s) {
                Text(profile.name).font(AppTypography.largeTitle)
                Text("\(profile.age)").font(AppTypography.title2).opacity(0.9)
                if profile.isVerified {
                    Image(systemName: "checkmark.seal.fill").foregroundStyle(.blue)
                }
                Spacer()
            }

            HStack(spacing: AppSpacing.xs) {
                Image(systemName: "mappin.and.ellipse")
                Text(profile.city)
                Text("·")
                Text(profile.hearingStatus.title)
            }
            .font(AppTypography.subheadline)
            .opacity(0.9)

            if !profile.bio.isEmpty {
                Text(profile.bio)
                    .font(AppTypography.body)
                    .lineLimit(3)
                    .opacity(0.95)
            }

            HStack(spacing: AppSpacing.xs) {
                ForEach(profile.interests.prefix(4), id: \.self) { tag in
                    Text(tag)
                        .font(AppTypography.caption)
                        .padding(.horizontal, AppSpacing.s)
                        .padding(.vertical, 4)
                        .background(.ultraThinMaterial)
                        .clipShape(Capsule())
                }
            }
        }
        .foregroundStyle(.white)
        .padding(AppSpacing.l)
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.6)],
                startPoint: .top,
                endPoint: .bottom
            )
        )
    }
}
