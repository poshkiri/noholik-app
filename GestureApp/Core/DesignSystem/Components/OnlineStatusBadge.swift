import SwiftUI

/// Small green dot that overlays an avatar to signal "online".
/// Usage: place in a `ZStack(alignment: .bottomTrailing)` on top of
/// an avatar view.
struct OnlineStatusBadge: View {
    var size: CGFloat = 13

    var body: some View {
        Circle()
            .fill(Color.green)
            .frame(width: size, height: size)
            .overlay(Circle().strokeBorder(.white, lineWidth: 2.5))
    }
}
