import SwiftUI
import UIKit

// MARK: - Haptic Feedback Manager
final class HapticManager {
    static let shared = HapticManager()
    private init() {}
    
    func selection() {
        UISelectionFeedbackGenerator().selectionChanged()
    }
    
    func impact(_ style: UIImpactFeedbackGenerator.FeedbackStyle = .medium) {
        let generator = UIImpactFeedbackGenerator(style: style)
        generator.prepare()
        generator.impactOccurred()
    }
    
    func notification(_ type: UINotificationFeedbackGenerator.FeedbackType) {
        let generator = UINotificationFeedbackGenerator()
        generator.prepare()
        generator.notificationOccurred(type)
    }
}

// MARK: - App Color Theme
struct AppTheme {
    static let primaryBackground = Color(uiColor: .systemGroupedBackground)
    static let secondaryBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let cardBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let tertiaryBackground = Color(uiColor: .tertiarySystemGroupedBackground)
    
    static let accentEmerald = Color(red: 0.10, green: 0.75, blue: 0.50)
    static let accentEmeraldDark = Color(red: 0.06, green: 0.62, blue: 0.40)
    static let accentBlue = Color(red: 0.12, green: 0.53, blue: 0.96)
    static let accentPurple = Color(red: 0.55, green: 0.35, blue: 0.95)
    static let accentOrange = Color(red: 1.0, green: 0.58, blue: 0.0)
    static let accentRed = Color(red: 0.95, green: 0.26, blue: 0.21)
    static let accentGold = Color(red: 0.98, green: 0.75, blue: 0.15)
    
    static let subtleGray = Color(uiColor: .secondaryLabel)
    static let dividerColor = Color(uiColor: .separator)
    
    // Gradients
    static let emeraldGradient = LinearGradient(
        colors: [Color(red: 0.12, green: 0.80, blue: 0.54), Color(red: 0.06, green: 0.64, blue: 0.42)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let blueGradient = LinearGradient(
        colors: [Color(red: 0.20, green: 0.60, blue: 1.0), Color(red: 0.08, green: 0.44, blue: 0.88)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let purpleGradient = LinearGradient(
        colors: [Color(red: 0.64, green: 0.42, blue: 1.0), Color(red: 0.48, green: 0.26, blue: 0.88)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let orangeGradient = LinearGradient(
        colors: [Color(red: 1.0, green: 0.65, blue: 0.18), Color(red: 0.94, green: 0.45, blue: 0.08)],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
    
    static let cardBorder = Color.primary.opacity(0.06)
}

// MARK: - Bounce Button Style
struct BounceButtonStyle: ButtonStyle {
    var scaleAmount: CGFloat = 0.97
    var haptic: Bool = true
    
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? scaleAmount : 1.0)
            .animation(.spring(response: 0.25, dampingFraction: 0.65), value: configuration.isPressed)
            .onChange(of: configuration.isPressed) { _, isPressed in
                if isPressed && haptic {
                    HapticManager.shared.impact(.light)
                }
            }
    }
}

// MARK: - Primary Button Modifier
struct PrimaryButtonModifier: ViewModifier {
    var backgroundColor: Color = AppTheme.accentEmerald
    var gradient: LinearGradient? = AppTheme.emeraldGradient
    var foregroundColor: Color = .white
    
    func body(content: Content) -> some View {
        content
            .font(.headline)
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: 54)
            .background(gradient != nil ? AnyView(gradient!) : AnyView(backgroundColor))
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .shadow(color: backgroundColor.opacity(0.35), radius: 10, x: 0, y: 5)
    }
}

// MARK: - Card Container Modifier
struct CleanCardModifier: ViewModifier {
    var cornerRadius: CGFloat = 20
    var hasBorder: Bool = true
    
    func body(content: Content) -> some View {
        content
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: cornerRadius, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: cornerRadius, style: .continuous)
                    .stroke(hasBorder ? AppTheme.cardBorder : Color.clear, lineWidth: 1)
            )
            .shadow(color: Color.black.opacity(0.03), radius: 8, x: 0, y: 3)
    }
}

// MARK: - View Extensions
extension View {
    func primaryButtonStyle(bg: Color = AppTheme.accentEmerald, gradient: LinearGradient? = AppTheme.emeraldGradient) -> some View {
        self.modifier(PrimaryButtonModifier(backgroundColor: bg, gradient: gradient))
            .buttonStyle(BounceButtonStyle())
    }
    
    func cleanCardStyle(cornerRadius: CGFloat = 20, hasBorder: Bool = true) -> some View {
        self.modifier(CleanCardModifier(cornerRadius: cornerRadius, hasBorder: hasBorder))
    }
    
    func bounceable(haptic: Bool = true) -> some View {
        self.buttonStyle(BounceButtonStyle(haptic: haptic))
    }
}
