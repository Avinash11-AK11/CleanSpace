import SwiftUI

struct SpaceFreedView: View {
    @ObservedObject private var cleanupManager = CleanupManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            
            // Celebration icon
            ZStack {
                Circle()
                    .fill(AppTheme.accentEmerald.opacity(0.15))
                    .frame(width: 110, height: 110)
                
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 64))
                    .foregroundColor(AppTheme.accentEmerald)
            }
            
            VStack(spacing: 8) {
                Text("Clean Complete!")
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                
                Text("You've successfully freed up space on your iPhone")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.subtleGray)
            }
            
            // Stats card
            VStack(spacing: 12) {
                Text("SPACE RECOVERED")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.subtleGray)
                    .tracking(1.0)
                
                Text(ByteCountFormatter.string(fromByteCount: cleanupManager.lastFreedBytes, countStyle: .file))
                    .font(.system(size: 44, weight: .heavy, design: .rounded))
                    .foregroundColor(AppTheme.accentEmerald)
                
                Text("\(cleanupManager.lastFreedItemCount) items safely removed")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.subtleGray)
            }
            .frame(maxWidth: .infinity)
            .padding(24)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
            .padding(.horizontal, 24)
            
            // Device Health Note
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .foregroundColor(AppTheme.accentEmerald)
                Text("Your iPhone has more room for memories and performance.")
                    .font(.caption)
                    .foregroundColor(AppTheme.subtleGray)
            }
            
            Spacer()
            
            Button("Done") {
                dismiss()
            }
            .primaryButtonStyle(bg: AppTheme.accentEmerald)
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .background(AppTheme.primaryBackground)
        .navigationBarBackButtonHidden(true)
    }
}
