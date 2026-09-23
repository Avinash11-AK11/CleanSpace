import SwiftUI

struct StorageGaugeView: View {
    let storageInfo: StorageInfo
    let cleanableBytes: Int64
    
    private var healthTitle: String {
        if storageInfo.usedPercentage > 0.90 {
            return "Critical Space"
        } else if storageInfo.usedPercentage > 0.75 {
            return "Moderate Usage"
        } else {
            return "Optimal Space"
        }
    }
    
    private var healthColor: Color {
        if storageInfo.usedPercentage > 0.90 {
            return AppTheme.accentOrange
        } else if storageInfo.usedPercentage > 0.75 {
            return AppTheme.accentBlue
        } else {
            return AppTheme.accentEmerald
        }
    }
    
    var body: some View {
        VStack(spacing: 16) {
            // Header Row
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 6) {
                        Text("STORAGE")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.subtleGray)
                            .tracking(1.2)
                        
                        Text(healthTitle)
                            .font(.system(size: 10, weight: .bold))
                            .foregroundColor(healthColor)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(healthColor.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text(storageInfo.formattedUsed)
                            .font(.system(size: 30, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("used of \(storageInfo.formattedTotal)")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.subtleGray)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text("Free Space")
                        .font(.caption)
                        .foregroundColor(AppTheme.subtleGray)
                    Text(storageInfo.formattedFree)
                        .font(.system(size: 18, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.accentEmerald)
                }
            }
            
            // Storage Bar Track
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
                    
                    // Used bar gradient
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
                        HStack(spacing: 0) {
                            Spacer().frame(width: max(0, usedWidth - cleanableWidth))
                            Capsule()
                                .fill(AppTheme.accentEmerald)
                                .frame(width: max(10, cleanableWidth), height: 14)
                        }
                    }
                }
            }
            .frame(height: 14)
            
            // Legend
            HStack {
                HStack(spacing: 6) {
                    Circle()
                        .fill(AppTheme.accentBlue)
                        .frame(width: 8, height: 8)
                    Text("System & Apps (\(Int(storageInfo.usedPercentage * 100))%)")
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
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.accentEmerald)
                    }
                }
            }
        }
        .padding(20)
        .cleanCardStyle(cornerRadius: 22)
    }
}
