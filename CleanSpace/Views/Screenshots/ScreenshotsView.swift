import SwiftUI

struct ScreenshotsView: View {
    @Binding var screenshots: [PhotoItem]
    @ObservedObject private var cleanupManager = CleanupManager.shared
    
    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    var allSelected: Bool {
        guard !screenshots.isEmpty else { return false }
        return screenshots.allSatisfy { cleanupManager.selectedScreenshotIds.contains($0.id) }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 16) {
                    if screenshots.isEmpty {
                        VStack(spacing: 16) {
                            Spacer().frame(height: 60)
                            Image(systemName: "checkmark.seal.fill")
                                .font(.system(size: 60))
                                .foregroundColor(AppTheme.accentEmerald)
                            Text("No Screenshots Found")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("Your screenshot gallery is completely clean!")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.subtleGray)
                        }
                        .padding()
                    } else {
                        // Quick Action Header
                        HStack {
                            Text("\(screenshots.count) Screenshots")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppTheme.subtleGray)
                            
                            Spacer()
                            
                            Button(allSelected ? "Deselect All" : "Select All") {
                                HapticManager.shared.selection()
                                withAnimation {
                                    if allSelected {
                                        cleanupManager.deselectAllScreenshots()
                                    } else {
                                        cleanupManager.selectAllScreenshots(screenshots)
                                    }
                                }
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.accentBlue)
                        }
                        .padding(.horizontal)
                        
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(screenshots) { item in
                                let isSelected = cleanupManager.selectedScreenshotIds.contains(item.id)
                                
                                Button {
                                    HapticManager.shared.impact(.light)
                                    withAnimation(.spring(response: 0.3)) {
                                        cleanupManager.toggleScreenshot(item)
                                    }
                                } label: {
                                    ZStack(alignment: .topTrailing) {
                                        PHAssetThumbnailView(asset: item.asset)
                                            .aspectRatio(1, contentMode: .fill)
                                            .clipped()
                                            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12, style: .continuous)
                                                    .stroke(isSelected ? AppTheme.accentEmerald : AppTheme.cardBorder, lineWidth: isSelected ? 3 : 1)
                                            )
                                        
                                        // Selection indicator
                                        ZStack {
                                            Circle()
                                                .fill(isSelected ? AppTheme.accentEmerald : Color.black.opacity(0.4))
                                                .frame(width: 26, height: 26)
                                            
                                            Image(systemName: isSelected ? "checkmark" : "circle")
                                                .font(.system(size: 12, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                        .padding(6)
                                        
                                        // File Size tag at bottom
                                        VStack {
                                            Spacer()
                                            HStack {
                                                Text(item.formattedSize)
                                                    .font(.system(size: 10, weight: .semibold))
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 6)
                                                    .padding(.vertical, 2)
                                                    .background(Color.black.opacity(0.6))
                                                    .clipShape(Capsule())
                                                Spacer()
                                            }
                                            .padding(4)
                                        }
                                    }
                                }
                                .buttonStyle(PlainButtonStyle())
                            }
                        }
                        .padding(.horizontal, 12)
                    }
                    
                    Spacer().frame(height: 100)
                }
                .padding(.top, 8)
            }
            
            // Bottom floating glass dock if items selected
            if cleanupManager.totalSelectedCount > 0 {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cleanupManager.formattedTotalSelectedCount)
                            .font(.subheadline)
                            .fontWeight(.bold)
                        Text("Estimated: \(cleanupManager.formattedEstimatedBytes)")
                            .font(.caption)
                            .foregroundColor(AppTheme.accentEmerald)
                    }
                    Spacer()
                    NavigationLink(destination: ReviewView()) {
                        HStack(spacing: 6) {
                            Text("Review Cleanup")
                            Image(systemName: "arrow.right")
                        }
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(AppTheme.accentEmerald)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(BounceButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .background(AppTheme.primaryBackground)
        .navigationTitle("Screenshots")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            syncDeletedScreenshots()
        }
        .onChange(of: cleanupManager.deletedAssetIds) {
            syncDeletedScreenshots()
        }
    }
    
    private func syncDeletedScreenshots() {
        guard !cleanupManager.deletedAssetIds.isEmpty else { return }
        withAnimation {
            screenshots.removeAll { cleanupManager.deletedAssetIds.contains($0.id) }
        }
    }
}
