import SwiftUI

struct PrimaryButton: View {
    enum Style { case filled, outlined, ghost }

    let title: String
    var systemImage: String? = nil
    var style: Style = .filled
    var isLoading: Bool = false
    var isEnabled: Bool = true
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: AppSpacing.s) {
                if isLoading {
                    ProgressView().tint(foreground)
                } else if let systemImage {
                    Image(systemName: systemImage)
                }
                Text(title).font(AppTypography.bodyBold)
            }
            .frame(maxWidth: .infinity, minHeight: 52)
            .foregroundStyle(foreground)
            .background(background)
            .overlay(
                RoundedRectangle(cornerRadius: AppRadius.l)
                    .strokeBorder(borderColor, lineWidth: style == .outlined ? 1.5 : 0)
            )
            .clipShape(RoundedRectangle(cornerRadius: AppRadius.l))
            .contentShape(Rectangle())
        }
        .disabled(!isEnabled || isLoading)
        .opacity(isEnabled ? 1 : 0.5)
        .sensoryFeedback(.impact, trigger: isLoading)
    }

    private var foreground: Color {
        switch style {
        case .filled: AppColor.textOnAccent
        case .outlined, .ghost: AppColor.accent
        }
    }

    private var background: Color {
        switch style {
        case .filled: AppColor.accent
        case .outlined: .clear
        case .ghost: AppColor.accentSoft
        }
    }

    private var borderColor: Color {
        style == .outlined ? AppColor.accent : .clear
    }
}

#Preview {
    VStack(spacing: AppSpacing.l) {
        PrimaryButton(title: "Продолжить", action: {})
        PrimaryButton(title: "Назад", style: .outlined, action: {})
        PrimaryButton(title: "Загрузка", isLoading: true, action: {})
    }
    .padding()
}
