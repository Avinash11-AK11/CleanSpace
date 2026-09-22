import Foundation
import Photos

final class VideoScanner: Sendable {
    static let shared = VideoScanner()
    
    private init() {}
    
    /// Fetches all videos sorted from largest to smallest
    func fetchLargeVideos(minimumBytes: Int64 = 0) -> [VideoItem] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        
        let result = PHAsset.fetchAssets(with: .video, options: options)
        var items: [VideoItem] = []
        items.reserveCapacity(result.count)
        
        result.enumerateObjects { asset, _, _ in
            let size = self.estimateVideoSize(asset: asset)
            if size >= minimumBytes {
                items.append(VideoItem(asset: asset, fileSize: size))
            }
        }
        
        // Sort from largest to smallest
        items.sort { $0.fileSize > $1.fileSize }
        return items
    }
    
    /// Finds groups of duplicate or identical videos based on matching duration, resolution, and file size
    func findDuplicateVideoGroups(videos: [VideoItem]) -> [VideoGroup] {
        guard videos.count >= 2 else { return [] }
        
        var visited = Set<String>()
        var groups: [VideoGroup] = []
        
        for i in 0..<videos.count {
            let v1 = videos[i]
            if visited.contains(v1.id) { continue }
            
            var currentGroup: [VideoItem] = [v1]
            
            for j in (i + 1)..<videos.count {
                let v2 = videos[j]
                if visited.contains(v2.id) { continue }
                
                if areVideosDuplicate(v1, v2) {
                    currentGroup.append(v2)
                    visited.insert(v2.id)
                }
            }
            
            if currentGroup.count >= 2 {
                visited.insert(v1.id)
                
                // Pick best video to keep (favorite, earliest creation date / original)
                let bestVideo = selectBestVideo(from: currentGroup)
                
                let group = VideoGroup(
                    id: "video-group-\(v1.id)",
                    recommendedBestId: bestVideo.id,
                    videos: currentGroup
                )
                groups.append(group)
            }
        }
        
        // Sort duplicate groups by cleanable size descending
        groups.sort { $0.cleanableSize > $1.cleanableSize }
        return groups
    }
    
    /// Evaluates if two videos are duplicate or near-identical
    private func areVideosDuplicate(_ v1: VideoItem, _ v2: VideoItem) -> Bool {
        // 1. Duration check (within 0.25 seconds)
        let durationDiff = abs(v1.duration - v2.duration)
        guard durationDiff <= 0.25 else { return false }
        
        // 2. Resolution check (same dimensions)
        let sameDimensions = (v1.pixelWidth == v2.pixelWidth && v1.pixelHeight == v2.pixelHeight) ||
                             (v1.pixelWidth == v2.pixelHeight && v1.pixelHeight == v2.pixelWidth)
        guard sameDimensions else { return false }
        
        // 3. File size check (within 3% or within 100KB)
        let maxSize = max(v1.fileSize, v2.fileSize)
        if maxSize > 0 {
            let sizeDiff = abs(v1.fileSize - v2.fileSize)
            let allowedDiff = max(150_000, Int64(Double(maxSize) * 0.03))
            guard sizeDiff <= allowedDiff else { return false }
        }
        
        return true
    }
    
    /// Selects the best original video from a duplicate group
    private func selectBestVideo(from videos: [VideoItem]) -> VideoItem {
        // Preference:
        // 1. Favorited video
        // 2. Earliest creation date (original capture)
        // 3. Largest file size (highest fidelity)
        return videos.max { a, b in
            if a.asset.isFavorite != b.asset.isFavorite {
                return !a.asset.isFavorite && b.asset.isFavorite
            }
            let aDate = a.creationDate ?? .distantFuture
            let bDate = b.creationDate ?? .distantFuture
            if aDate != bDate {
                return aDate > bDate // Earlier date is preferred
            }
            return a.fileSize < b.fileSize
        } ?? videos[0]
    }
    
    private func estimateVideoSize(asset: PHAsset) -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        if let first = resources.first,
           let size = first.value(forKey: "fileSize") as? Int64, size > 0 {
            return size
        }
        // Fallback calculation based on duration & 1080p average bitrate (~15 Mbps ≈ 1.8 MB/sec)
        let seconds = asset.duration
        let estimatedBytes = Int64(seconds * 1_800_000)
        return max(5_000_000, estimatedBytes)
    }
}
