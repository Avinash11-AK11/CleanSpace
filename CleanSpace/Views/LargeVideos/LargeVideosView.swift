import SwiftUI
import Photos
import AVKit

struct LargeVideosView: View {
    @State var videos: [VideoItem]
    @ObservedObject private var cleanupManager = CleanupManager.shared
    @State private var previewVideoAsset: PHAsset?
    @State private var previewPlayer: AVPlayer?
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 16) {
                    if videos.isEmpty {
                        VStack(spacing: 16) {
                            Spacer().frame(height: 60)
                            Image(systemName: "film.stack")
                                .font(.system(size: 60))
                                .foregroundColor(AppTheme.accentEmerald)
                            Text("No Large Videos Found")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("Your library has no storage-hogging videos.")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.subtleGray)
                        }
                        .padding()
                    } else {
                        HStack {
                            Text("Sorted by size (Largest to Smallest)")
                                .font(.caption)
                                .foregroundColor(AppTheme.subtleGray)
                            Spacer()
                            Text("\(videos.count) Videos")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(AppTheme.subtleGray)
                        }
                        .padding(.horizontal)
                        
                        LazyVStack(spacing: 12) {
                            ForEach(videos) { video in
                                let isSelected = cleanupManager.selectedVideoIds.contains(video.id)
                                
                                HStack(spacing: 14) {
                                    // Thumbnail with Play button
                                    Button {
                                        loadAndPlayVideo(asset: video.asset)
                                    } label: {
                                        ZStack {
                                            PHAssetThumbnailView(asset: video.asset)
                                                .frame(width: 84, height: 84)
                                                .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                            
                                            Circle()
                                                .fill(Color.black.opacity(0.5))
                                                .frame(width: 32, height: 32)
                                            
                                            Image(systemName: "play.fill")
                                                .font(.system(size: 14))
                                                .foregroundColor(.white)
                                                .offset(x: 1)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                    
                                    // Video Details
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(video.formattedSize)
                                            .font(.headline)
                                            .fontWeight(.bold)
                                            .foregroundColor(.primary)
                                        
                                        HStack(spacing: 8) {
                                            Text(video.qualityLabel)
                                                .font(.caption2)
                                                .fontWeight(.bold)
                                                .padding(.horizontal, 6)
                                                .padding(.vertical, 2)
                                                .background(AppTheme.accentOrange.opacity(0.15))
                                                .foregroundColor(AppTheme.accentOrange)
                                                .clipShape(RoundedRectangle(cornerRadius: 6))
                                            
                                            Text(video.formattedDuration)
                                                .font(.caption)
                                                .foregroundColor(AppTheme.subtleGray)
                                        }
                                        
                                        if let date = video.creationDate {
                                            Text(date.formatted(date: .abbreviated, time: .omitted))
                                                .font(.caption2)
                                                .foregroundColor(AppTheme.subtleGray)
                                        }
                                    }
                                    
                                    Spacer()
                                    
                                    // Select checkbox
                                    Button {
                                        withAnimation(.spring(response: 0.3)) {
                                            cleanupManager.toggleVideo(video)
                                        }
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .fill(isSelected ? AppTheme.accentEmerald : Color(uiColor: .systemFill))
                                                .frame(width: 28, height: 28)
                                            
                                            Image(systemName: isSelected ? "checkmark" : "circle")
                                                .font(.system(size: 14, weight: .bold))
                                                .foregroundColor(isSelected ? .white : AppTheme.subtleGray)
                                        }
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                                .padding(12)
                                .background(AppTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                                        .stroke(isSelected ? AppTheme.accentEmerald : Color.clear, lineWidth: 2)
                                )
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer().frame(height: 100)
                }
                .padding(.top, 8)
            }
            
            // Floating review bar
            if cleanupManager.totalSelectedCount > 0 {
                VStack(spacing: 0) {
                    Divider()
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(cleanupManager.totalSelectedCount) items selected")
                                .font(.subheadline)
                                .fontWeight(.bold)
                            Text("Frees: \(cleanupManager.formattedEstimatedBytes)")
                                .font(.caption)
                                .foregroundColor(AppTheme.accentEmerald)
                        }
                        Spacer()
                        NavigationLink(destination: ReviewView {
                            withAnimation {
                                videos.removeAll { cleanupManager.selectedVideoIds.contains($0.id) }
                            }
                        }) {
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
        .navigationTitle("Large Videos")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $previewVideoAsset) { asset in
            if let player = previewPlayer {
                VideoPlayer(player: player)
                    .edgesIgnoringSafeArea(.all)
                    .onAppear {
                        player.play()
                    }
                    .onDisappear {
                        player.pause()
                        previewPlayer = nil
                    }
            } else {
                ProgressView("Loading preview...")
            }
        }
    }
    
    private func loadAndPlayVideo(asset: PHAsset) {
        let options = PHVideoRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .highQualityFormat
        
        PHImageManager.default().requestPlayerItem(forVideo: asset, options: options) { item, _ in
            DispatchQueue.main.async {
                if let item = item {
                    self.previewPlayer = AVPlayer(playerItem: item)
                    self.previewVideoAsset = asset
                }
            }
        }
    }
}

extension PHAsset: @retroactive Identifiable {
    public var id: String { localIdentifier }
}
