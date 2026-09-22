import Foundation
import Photos

final class VideoScanner: Sendable {
    static let shared = VideoScanner()
    
    private init() {}
    
    /// Fetches videos sorted from largest to smallest
    func fetchLargeVideos(minimumBytes: Int64 = 5_000_000) -> [VideoItem] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.video.rawValue)
        
        let result = PHAsset.fetchAssets(with: .video, options: options)
        var items: [VideoItem] = []
        items.reserveCapacity(result.count)
        
        result.enumerateObjects { asset, _, _ in
            let size = self.estimateVideoSize(asset: asset)
            if size >= minimumBytes || result.count < 10 {
                items.append(VideoItem(asset: asset, fileSize: size))
            }
        }
        
        // Sort from largest to smallest
        items.sort { $0.fileSize > $1.fileSize }
        return items
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
