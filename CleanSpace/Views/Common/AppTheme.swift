import SwiftUI

struct AppTheme {
    static let primaryBackground = Color(uiColor: .systemGroupedBackground)
    static let secondaryBackground = Color(uiColor: .secondarySystemGroupedBackground)
    static let cardBackground = Color(uiColor: .tertiarySystemGroupedBackground)
    
    static let accentEmerald = Color(red: 0.10, green: 0.75, blue: 0.50)
    static let accentBlue = Color(red: 0.12, green: 0.53, blue: 0.96)
    static let accentPurple = Color(red: 0.55, green: 0.35, blue: 0.95)
    static let accentOrange = Color(red: 1.0, green: 0.58, blue: 0.0)
    static let accentRed = Color(red: 0.95, green: 0.26, blue: 0.21)
    
    static let subtleGray = Color(uiColor: .secondaryLabel)
}

struct PrimaryButtonModifier: ViewModifier {
    var backgroundColor: Color = AppTheme.accentEmerald
    var foregroundColor: Color = .white
    
    func body(content: Content) -> some View {
        content
            .font(.headline)
            .foregroundColor(foregroundColor)
            .frame(maxWidth: .infinity)
            .frame(height: 52)
            .background(backgroundColor)
            .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            .shadow(color: backgroundColor.opacity(0.3), radius: 8, x: 0, y: 4)
    }
}

extension View {
    func primaryButtonStyle(bg: Color = AppTheme.accentEmerald) -> some View {
        self.modifier(PrimaryButtonModifier(backgroundColor: bg))
    }
}
