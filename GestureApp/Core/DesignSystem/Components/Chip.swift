import SwiftUI

struct Chip: View {
    let title: String
    var isSelected: Bool = false
    var action: (() -> Void)? = nil

    var body: some View {
        let content = Text(title)
            .font(AppTypography.subheadline)
            .padding(.horizontal, AppSpacing.l)
            .padding(.vertical, AppSpacing.s)
            .foregroundStyle(isSelected ? AppColor.textOnAccent : AppColor.textPrimary)
            .background(isSelected ? AppColor.accent : AppColor.surfaceElevated)
            .clipShape(Capsule())
            .overlay(
                Capsule().strokeBorder(
                    isSelected ? .clear : AppColor.divider,
                    lineWidth: 1
                )
            )

        if let action {
            Button(action: action) { content }
                .buttonStyle(.plain)
        } else {
            content
        }
    }
}
