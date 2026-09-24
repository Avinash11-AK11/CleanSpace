//
//  LargeVideosView.swift
//  CleanSpace
//
//  Created by Avinash Chavda on 22/09/2026, 06:03 PM.
//  Copyright © 2026 Avinash Chavda. All rights reserved.
//

import SwiftUI
import Photos
import AVKit

struct LargeVideosView: View {
    @Binding var videos: [VideoItem]
    @Binding var duplicateGroups: [VideoGroup]
    
    @ObservedObject private var cleanupManager = CleanupManager.shared
    @State private var previewVideoAsset: PHAsset?
    @State private var previewPlayer: AVPlayer?
    @State private var selectedTab: VideoTab = .duplicates
    @State private var videoToCompress: VideoItem? = nil
    
    enum VideoTab: String, CaseIterable, Identifiable {
        case duplicates = "Duplicates"
        case allVideos = "All Large Videos"
        var id: String { rawValue }
    }
    
    init(videos: Binding<[VideoItem]>, duplicateGroups: Binding<[VideoGroup]>) {
        self._videos = videos
        self._duplicateGroups = duplicateGroups
        _selectedTab = State(initialValue: duplicateGroups.wrappedValue.isEmpty ? .allVideos : .duplicates)
    }
    
    // Set of IDs that are marked as duplicate
    private var duplicateVideoIds: Set<String> {
        Set(duplicateGroups.flatMap { $0.videos.map { $0.id } })
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 16) {
                    // Segmented Picker
                    Picker("Video Filter", selection: $selectedTab) {
                        Text("Duplicates (\(duplicateGroups.count))").tag(VideoTab.duplicates)
                        Text("All Videos (\(videos.count))").tag(VideoTab.allVideos)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 4)
                    
                    if selectedTab == .duplicates {
                        duplicatesTabContent
                    } else {
                        allVideosTabContent
                    }
                    
                    Spacer().frame(height: 100)
                }
                .padding(.top, 8)
            }
            
            // Floating glass action bar
            if cleanupManager.totalSelectedCount > 0 {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cleanupManager.formattedTotalSelectedCount)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                        Text("Frees: \(cleanupManager.formattedEstimatedBytes)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.accentEmerald)
                    }
                    Spacer()
                    NavigationLink(destination: ReviewView()) {
                        HStack(spacing: 6) {
                            Text("Review Cleanup")
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(AppTheme.emeraldGradient)
                        .clipShape(Capsule())
                        .shadow(color: AppTheme.accentEmerald.opacity(0.35), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(BounceButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(AppTheme.primaryBackground)
        .navigationTitle("Videos")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            reloadVideos()
        }
        .onChange(of: cleanupManager.deletedAssetIds) {
            reloadVideos()
        }
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
        .sheet(item: $videoToCompress) { video in
            VideoCompressorView(video: video) { newAssetId, originalDeleted in
                reloadVideos(newAssetId: newAssetId)
            }
            .presentationDragIndicator(.visible)
        }
    }
    
    // MARK: - Duplicates Tab
    @ViewBuilder
    private var duplicatesTabContent: some View {
        if duplicateGroups.isEmpty {
            VStack(spacing: 16) {
                Spacer().frame(height: 60)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(AppTheme.accentEmerald)
                Text("No Duplicate Videos")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("All your videos are unique. No redundant copies found!")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.subtleGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }
            .padding()
        } else {
            // Quick action banner
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(duplicateGroups.count == 1 ? "1 Duplicate Group" : "\(duplicateGroups.count) Duplicate Groups")
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text("Best original video kept with ⭐")
                        .font(.caption)
                        .foregroundColor(AppTheme.subtleGray)
                }
                Spacer()
                
                HStack(spacing: 8) {
                    Button("Keep All") {
                        withAnimation {
                            for group in duplicateGroups {
                                for video in group.videos {
                                    cleanupManager.selectedVideoIds.remove(video.id)
                                }
                            }
                        }
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(AppTheme.accentEmerald.opacity(0.12))
                    .foregroundColor(AppTheme.accentEmerald)
                    .clipShape(Capsule())
                    
                    Button("Auto-Select") {
                        withAnimation {
                            cleanupManager.selectAllDuplicateVideosExcludingBest(groups: duplicateGroups)
                        }
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 7)
                    .background(AppTheme.accentBlue.opacity(0.12))
                    .foregroundColor(AppTheme.accentBlue)
                    .clipShape(Capsule())
                }
            }
            .padding(.horizontal)
            
            LazyVStack(spacing: 16) {
                ForEach(duplicateGroups) { group in
                    DuplicateVideoGroupCard(
                        group: group,
                        onPlay: { asset in
                            loadAndPlayVideo(asset: asset)
                        },
                        onCompress: { video in
                            videoToCompress = video
                        }
                    )
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - All Videos Tab
    @ViewBuilder
    private var allVideosTabContent: some View {
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
                Text(videos.count == 1 ? "1 Video" : "\(videos.count) Videos")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.subtleGray)
            }
            .padding(.horizontal)
            
            LazyVStack(spacing: 12) {
                ForEach(videos) { video in
                    let isSelected = cleanupManager.selectedVideoIds.contains(video.id)
                    let isDuplicate = duplicateVideoIds.contains(video.id)
                    
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
                            
                            HStack(spacing: 6) {
                                Text(video.qualityLabel)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppTheme.accentOrange.opacity(0.15))
                                    .foregroundColor(AppTheme.accentOrange)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                
                                if isDuplicate {
                                    Text("Duplicate")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                        .lineLimit(1)
                                        .fixedSize(horizontal: true, vertical: false)
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(AppTheme.accentBlue.opacity(0.15))
                                        .foregroundColor(AppTheme.accentBlue)
                                        .clipShape(RoundedRectangle(cornerRadius: 6))
                                }
                                
                                Text(video.formattedDuration)
                                    .font(.caption)
                                    .foregroundColor(AppTheme.subtleGray)
                                    .lineLimit(1)
                            }
                            
                            if let date = video.creationDate {
                                Text(date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption2)
                                    .foregroundColor(AppTheme.subtleGray)
                            }
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 12) {
                            Button {
                                videoToCompress = video
                            } label: {
                                Image(systemName: "arrow.down.right.and.arrow.up.left")
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundColor(AppTheme.accentBlue)
                                    .padding(8)
                                    .background(AppTheme.accentBlue.opacity(0.12))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            
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
    }
    
    // MARK: - Reload Videos & Duplicates
    private func reloadVideos(newAssetId: String? = nil) {
        var updatedVideos = VideoScanner.shared.fetchLargeVideos()
        
        // If a newly compressed video was created and isn't in the initial fetch yet, fetch it directly
        if let newId = newAssetId, !updatedVideos.contains(where: { $0.id == newId }) {
            let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [newId], options: nil)
            if let newAsset = fetchResult.firstObject {
                let size = VideoScanner.shared.estimateVideoSize(asset: newAsset)
                updatedVideos.insert(VideoItem(asset: newAsset, fileSize: size), at: 0)
            }
        }
        
        // Exclude any deleted assets
        if !cleanupManager.deletedAssetIds.isEmpty {
            updatedVideos.removeAll { cleanupManager.deletedAssetIds.contains($0.id) }
        }
        
        withAnimation {
            self.videos = updatedVideos
            self.duplicateGroups = VideoScanner.shared.findDuplicateVideoGroups(videos: updatedVideos)
            
            for v in updatedVideos {
                cleanupManager.allVideosMap[v.id] = v
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

// MARK: - Duplicate Video Group Card
struct DuplicateVideoGroupCard: View {
    let group: VideoGroup
    let onPlay: (PHAsset) -> Void
    let onCompress: (VideoItem) -> Void
    @ObservedObject private var cleanupManager = CleanupManager.shared
    
    private var hasSelectedDuplicates: Bool {
        group.videos.contains { cleanupManager.selectedVideoIds.contains($0.id) }
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Text(group.videos.count == 1 ? "1 Video" : "\(group.videos.count) Videos")
                        .font(.caption)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(uiColor: .systemFill))
                        .clipShape(Capsule())
                    
                    Text("Frees \(group.formattedCleanableSize)")
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundColor(AppTheme.accentEmerald)
                }
                
                Spacer()
                
                HStack(spacing: 6) {
                    if hasSelectedDuplicates {
                        Button("Keep Both") {
                            withAnimation {
                                for video in group.videos {
                                    cleanupManager.selectedVideoIds.remove(video.id)
                                }
                            }
                        }
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.accentEmerald.opacity(0.12))
                        .foregroundColor(AppTheme.accentEmerald)
                        .clipShape(Capsule())
                    } else {
                        Button(group.videos.count - 1 == 1 ? "Select Duplicate" : "Select Duplicates") {
                            withAnimation {
                                guard let bestId = group.recommendedBestId else { return }
                                for video in group.videos where video.id != bestId {
                                    cleanupManager.selectedVideoIds.insert(video.id)
                                    cleanupManager.allVideosMap[video.id] = video
                                }
                            }
                        }
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(AppTheme.accentBlue.opacity(0.12))
                        .foregroundColor(AppTheme.accentBlue)
                        .clipShape(Capsule())
                        
                        Text("Keeping Both")
                            .font(.caption2)
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.accentEmerald)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(AppTheme.accentEmerald.opacity(0.1))
                            .clipShape(Capsule())
                    }
                }
            }
            
            Divider()
            
            VStack(spacing: 10) {
                ForEach(group.videos) { video in
                    let isBest = video.id == group.recommendedBestId
                    let isSelected = cleanupManager.selectedVideoIds.contains(video.id)
                    
                    HStack(spacing: 12) {
                        // Thumbnail with Play
                        Button {
                            onPlay(video.asset)
                        } label: {
                            ZStack {
                                PHAssetThumbnailView(asset: video.asset)
                                    .frame(width: 68, height: 68)
                                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                                
                                Circle()
                                    .fill(Color.black.opacity(0.5))
                                    .frame(width: 26, height: 26)
                                
                                Image(systemName: "play.fill")
                                    .font(.system(size: 11))
                                    .foregroundColor(.white)
                                    .offset(x: 1)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                        
                        // Video details
                        VStack(alignment: .leading, spacing: 4) {
                            HStack(spacing: 6) {
                                Text(video.formattedSize)
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                                
                                if isBest {
                                    HStack(spacing: 2) {
                                        Image(systemName: "star.fill")
                                            .font(.system(size: 8))
                                        Text("Keep Best")
                                            .font(.system(size: 9, weight: .bold))
                                    }
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppTheme.accentOrange)
                                    .foregroundColor(.white)
                                    .clipShape(Capsule())
                                }
                            }
                            
                            HStack(spacing: 6) {
                                Text(video.qualityLabel)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .lineLimit(1)
                                    .fixedSize(horizontal: true, vertical: false)
                                    .padding(.horizontal, 5)
                                    .padding(.vertical, 1)
                                    .background(AppTheme.accentOrange.opacity(0.15))
                                    .foregroundColor(AppTheme.accentOrange)
                                    .clipShape(RoundedRectangle(cornerRadius: 4))
                                
                                Text(video.formattedDuration)
                                    .font(.caption)
                                    .foregroundColor(AppTheme.subtleGray)
                                    .lineLimit(1)
                            }
                            
                            if let date = video.creationDate {
                                Text(date.formatted(date: .abbreviated, time: .omitted))
                                    .font(.caption2)
                                    .foregroundColor(AppTheme.subtleGray)
                            }
                        }
                        
                        Spacer()
                        
                        HStack(spacing: 10) {
                            Button {
                                onCompress(video)
                            } label: {
                                Image(systemName: "arrow.down.right.and.arrow.up.left")
                                    .font(.system(size: 11, weight: .semibold))
                                    .foregroundColor(AppTheme.accentBlue)
                                    .padding(6)
                                    .background(AppTheme.accentBlue.opacity(0.12))
                                    .clipShape(Circle())
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            // Selection Checkbox
                            Button {
                                withAnimation(.spring(response: 0.3)) {
                                    cleanupManager.toggleVideo(video)
                                }
                            } label: {
                                ZStack {
                                    Circle()
                                        .fill(isSelected ? AppTheme.accentEmerald : Color(uiColor: .systemFill))
                                        .frame(width: 26, height: 26)
                                    
                                    Image(systemName: isSelected ? "checkmark" : "circle")
                                        .font(.system(size: 12, weight: .bold))
                                        .foregroundColor(isSelected ? .white : AppTheme.subtleGray)
                                }
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(8)
                    .background(Color(uiColor: .secondarySystemGroupedBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? AppTheme.accentEmerald : Color.clear, lineWidth: 2)
                    )
                }
            }
        }
        .padding(14)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}

extension PHAsset: @retroactive Identifiable {
    public var id: String { localIdentifier }
}
