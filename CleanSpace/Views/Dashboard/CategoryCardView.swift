//
//  CategoryCardView.swift
//  CleanSpace
//
//  Created by Avinash Chavda on 22/09/2026, 06:03 PM.
//  Copyright © 2026 Avinash Chavda. All rights reserved.
//

import SwiftUI

struct CategoryCardView: View {
    let title: String
    let subtitle: String
    let badgeText: String?
    let iconName: String
    let iconColor: Color
    var isWarning: Bool = false
    
    var body: some View {
        HStack(spacing: 15) {
            // Squircle icon container
            ZStack {
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .fill(iconColor.opacity(0.14))
                    .frame(width: 48, height: 48)
                
                RoundedRectangle(cornerRadius: 14, style: .continuous)
                    .stroke(iconColor.opacity(0.25), lineWidth: 1)
                    .frame(width: 48, height: 48)
                
                Image(systemName: iconName)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(iconColor)
            }
            
            // Text details
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
                    .foregroundColor(.primary)
                
                Text(subtitle)
                    .font(.system(size: 13, weight: .regular))
                    .foregroundColor(AppTheme.subtleGray)
                    .lineLimit(1)
            }
            
            Spacer()
            
            // Badge / Size highlight
            if let badgeText = badgeText {
                Text(badgeText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundColor(isWarning ? AppTheme.accentOrange : (badgeText == "Manage" ? AppTheme.accentBlue : AppTheme.accentEmerald))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(
                        Capsule()
                            .fill(isWarning ? AppTheme.accentOrange.opacity(0.12) : (badgeText == "Manage" ? AppTheme.accentBlue.opacity(0.12) : AppTheme.accentEmerald.opacity(0.12)))
                    )
            }
            
            Image(systemName: "chevron.right")
                .font(.system(size: 13, weight: .semibold))
                .foregroundColor(Color(uiColor: .tertiaryLabel))
        }
        .padding(16)
        .cleanCardStyle(cornerRadius: 18)
    }
}
