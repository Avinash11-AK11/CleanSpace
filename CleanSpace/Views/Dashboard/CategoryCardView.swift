import SwiftUI

struct CategoryCardView: View {
    let title: String
    let subtitle: String
    let badgeText: String?
    let iconName: String
    let iconColor: Color
    var isWarning: Bool = false
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon container
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 48, height: 48)
                
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            // Text details
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.headline)
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.subheadline)
                    .foregroundColor(AppTheme.subtleGray)
            }
            
            Spacer()
            
            // Badge / Size highlight
            if let badgeText = badgeText {
                Text(badgeText)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(isWarning ? AppTheme.accentOrange : .primary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(Color(uiColor: .systemFill))
                    .clipShape(Capsule())
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 14, weight: .semibold))
                .foregroundColor(Color(uiColor: .tertiaryLabel))
        }
        .padding(16)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
    }
}
