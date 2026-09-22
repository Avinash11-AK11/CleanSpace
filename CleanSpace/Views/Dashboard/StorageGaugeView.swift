import SwiftUI

struct StorageGaugeView: View {
    let storageInfo: StorageInfo
    let cleanableBytes: Int64
    
    var body: some View {
        VStack(spacing: 16) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("DEVICE STORAGE")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.subtleGray)
                        .tracking(1.0)
                    
                    Text("\(storageInfo.formattedUsed) used")
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                }
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Free Space")
                        .font(.caption)
                        .foregroundColor(AppTheme.subtleGray)
                    Text(storageInfo.formattedFree)
                        .font(.system(size: 16, weight: .semibold, design: .rounded))
                        .foregroundColor(AppTheme.accentEmerald)
                }
            }
            
            // Storage Bar
            GeometryReader { geometry in
                let totalWidth = geometry.size.width
                let usedWidth = totalWidth * CGFloat(min(1.0, max(0.0, storageInfo.usedPercentage)))
                let cleanablePercentage = storageInfo.totalBytes > 0 ? (Double(cleanableBytes) / Double(storageInfo.totalBytes)) : 0.0
                let cleanableWidth = min(usedWidth, totalWidth * CGFloat(cleanablePercentage))
                
                ZStack(alignment: .leading) {
                    // Total / Background track
                    Capsule()
                        .fill(Color(uiColor: .systemFill))
                        .frame(height: 14)
                    
                    // Used bar
                    Capsule()
                        .fill(
                            LinearGradient(
                                colors: [AppTheme.accentBlue, AppTheme.accentPurple],
                                startPoint: .leading,
                                endPoint: .trailing
                            )
                        )
                        .frame(width: max(14, usedWidth), height: 14)
                    
                    // Cleanable highlight overlay
                    if cleanableBytes > 0 {
                        Capsule()
                            .fill(AppTheme.accentEmerald)
                            .frame(width: max(6, cleanableWidth), height: 14)
                    }
                }
            }
            .frame(height: 14)
            
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppTheme.accentBlue)
                        .frame(width: 8, height: 8)
                    Text("System & Apps: \(Int(storageInfo.usedPercentage * 100))%")
                        .font(.caption2)
                        .foregroundColor(AppTheme.subtleGray)
                }
                
                Spacer()
                
                if cleanableBytes > 0 {
                    HStack(spacing: 6) {
                        Circle()
                            .fill(AppTheme.accentEmerald)
                            .frame(width: 8, height: 8)
                        Text("Cleanable: \(ByteCountFormatter.string(fromByteCount: cleanableBytes, countStyle: .file))")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.accentEmerald)
                    }
                }
            }
        }
        .padding(20)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 22, style: .continuous))
        .shadow(color: Color.black.opacity(0.04), radius: 10, x: 0, y: 4)
    }
}
