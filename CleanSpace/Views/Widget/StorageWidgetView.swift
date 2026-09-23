import SwiftUI

struct StorageWidgetView: View {
    @ObservedObject var viewModel: DashboardViewModel
    
    var body: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("HOME SCREEN WIDGET")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.subtleGray)
                .tracking(1.0)
                .padding(.horizontal)
            
            VStack(alignment: .leading, spacing: 14) {
                HStack(spacing: 8) {
                    Image(systemName: "square.grid.2x2.fill")
                        .foregroundColor(AppTheme.accentEmerald)
                    Text("Widget Live Preview")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Spacer()
                    Text("Interactive")
                        .font(.caption2.bold())
                        .foregroundColor(AppTheme.accentEmerald)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(AppTheme.accentEmerald.opacity(0.15))
                        .clipShape(Capsule())
                }
                
                // Embedded Widget Mockup
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 6) {
                        HStack(spacing: 6) {
                            Image(systemName: "internaldrive.fill")
                                .foregroundColor(Color.green)
                            Text("CleanSpace Storage")
                                .font(.caption.bold())
                                .foregroundColor(Color.gray)
                        }
                        
                        Text("\(viewModel.storageInfo.formattedUsed) Used")
                            .font(.system(size: 22, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                        
                        Text("Total: \(viewModel.storageInfo.formattedTotal)")
                            .font(.caption)
                            .foregroundColor(Color.gray)
                        
                        GeometryReader { proxy in
                            ZStack(alignment: .leading) {
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(Color.gray.opacity(0.35))
                                    .frame(height: 7)
                                
                                RoundedRectangle(cornerRadius: 4)
                                    .fill(LinearGradient(colors: [Color.green, Color.blue], startPoint: .leading, endPoint: .trailing))
                                    .frame(width: max(8, proxy.size.width * CGFloat(viewModel.storageInfo.usedPercentage)), height: 7)
                            }
                        }
                        .frame(height: 7)
                    }
                    
                    Spacer()
                    
                    ZStack {
                        Circle()
                            .stroke(Color.gray.opacity(0.3), lineWidth: 7)
                            .frame(width: 60, height: 60)
                        Circle()
                            .trim(from: 0.0, to: CGFloat(viewModel.storageInfo.usedPercentage))
                            .stroke(
                                LinearGradient(colors: [Color.green, Color.blue], startPoint: .topLeading, endPoint: .bottomTrailing),
                                style: StrokeStyle(lineWidth: 7, lineCap: .round)
                            )
                            .rotationEffect(.degrees(-90))
                            .frame(width: 60, height: 60)
                        Text("\(Int(viewModel.storageInfo.usedPercentage * 100))%")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(.white)
                    }
                }
                .padding(16)
                .background(Color(red: 0.12, green: 0.13, blue: 0.16))
                .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            }
            .padding(16)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .padding(.horizontal)
        }
    }
}
