import SwiftUI
import Photos

struct BlurryPhotosView: View {
    @Binding var blurryPhotos: [BlurryPhotoItem]
    @ObservedObject private var cleanupManager = CleanupManager.shared
    
    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    var allSelected: Bool {
        guard !blurryPhotos.isEmpty else { return false }
        return blurryPhotos.allSatisfy { cleanupManager.selectedPhotoIds.contains($0.id) }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 16) {
                    if blurryPhotos.isEmpty {
                        VStack(spacing: 16) {
                            Spacer().frame(height: 60)
                            Image(systemName: "camera.metering.matrix")
                                .font(.system(size: 60))
                                .foregroundColor(AppTheme.accentEmerald)
                            Text("No Blurry Photos Found")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("All photos in your library are clear and in focus!")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.subtleGray)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        // Quick Action Header
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(blurryPhotos.count == 1 ? "1 Blurry Photo" : "\(blurryPhotos.count) Blurry Photos")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                Text("Detected via optical edge sharpness")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.subtleGray)
                            }
                            
                            Spacer()
                            
                            Button(allSelected ? "Deselect All" : "Select All") {
                                withAnimation {
                                    if allSelected {
                                        for item in blurryPhotos {
                                            cleanupManager.selectedPhotoIds.remove(item.id)
                                        }
                                    } else {
                                        for item in blurryPhotos {
                                            cleanupManager.selectedPhotoIds.insert(item.id)
                                            cleanupManager.allPhotosMap[item.id] = item.photo
                                        }
                                    }
                                }
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.accentBlue)
                        }
                        .padding(.horizontal)
                        
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(blurryPhotos) { item in
                                let isSelected = cleanupManager.selectedPhotoIds.contains(item.id)
                                
                                Button {
                                    withAnimation(.spring(response: 0.3)) {
                                        cleanupManager.togglePhoto(item.photo)
                                    }
                                } label: {
                                    ZStack(alignment: .topTrailing) {
                                        PHAssetThumbnailView(asset: item.photo.asset)
                                            .aspectRatio(1, contentMode: .fill)
                                            .clipped()
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(isSelected ? AppTheme.accentEmerald : Color.clear, lineWidth: 3)
                                            )
                                        
                                        // Blurry Score Tag at Top Left
                                        VStack {
                                            HStack {
                                                HStack(spacing: 3) {
                                                    Image(systemName: "eye.slash.fill")
                                                        .font(.system(size: 8))
                                                    Text(item.formattedSharpness)
                                                        .font(.system(size: 8, weight: .bold))
                                                }
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(AppTheme.accentOrange.opacity(0.9))
                                                .clipShape(Capsule())
                                                
                                                Spacer()
                                            }
                                            Spacer()
                                        }
                                        .padding(4)
                                        
                                        // Selection checkmark at Top Right
                                        ZStack {
                                            Circle()
                                                .fill(isSelected ? AppTheme.accentEmerald : Color.black.opacity(0.4))
                                                .frame(width: 24, height: 24)
                                            
                                            Image(systemName: isSelected ? "checkmark" : "circle")
                                                .font(.system(size: 11, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                        .padding(6)
                                        
                                        // File Size tag at Bottom Left
                                        VStack {
                                            Spacer()
                                            HStack {
                                                Text(item.photo.formattedSize)
                                                    .font(.system(size: 9, weight: .semibold))
                                                    .foregroundColor(.white)
                                                    .padding(.horizontal, 5)
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
            
            // Bottom review prompt if items selected
            if cleanupManager.totalSelectedCount > 0 {
                VStack(spacing: 0) {
                    Divider()
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
                            Text("Review Cleanup")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(AppTheme.accentEmerald)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                }
            }
        }
        .background(AppTheme.primaryBackground)
        .navigationTitle("Blurry Photos")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            syncDeletedPhotos()
        }
        .onChange(of: cleanupManager.deletedAssetIds) {
            syncDeletedPhotos()
        }
    }
    
    private func syncDeletedPhotos() {
        guard !cleanupManager.deletedAssetIds.isEmpty else { return }
        withAnimation {
            blurryPhotos.removeAll { cleanupManager.deletedAssetIds.contains($0.id) }
        }
    }
}
