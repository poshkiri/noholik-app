import SwiftUI

struct AppTextField: View {
    let title: String
    @Binding var text: String
    var placeholder: String = ""
    var keyboard: UIKeyboardType = .default
    var contentType: UITextContentType? = nil
    var isSecure: Bool = false

    @FocusState private var focused: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: AppSpacing.xs) {
            Text(title)
                .font(AppTypography.caption)
                .foregroundStyle(AppColor.textSecondary)

            Group {
                if isSecure {
                    SecureField(placeholder, text: $text)
                } else {
                    TextField(placeholder, text: $text)
                }
            }
            .keyboardType(keyboard)
            .textContentType(contentType)
            .focused($focused)
            .font(AppTypography.body)
            .foregroundStyle(AppColor.textPrimary)
            .padding(.horizontal, AppSpacing.l)
            .padding(.vertical, AppSpacing.m)
            .background(AppColor.surfaceElevated)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.m)
                    .strokeBorder(focused ? AppColor.accent : AppColor.divider, lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.m))
        }
    }
}
