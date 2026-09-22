import Foundation
import Photos
import UIKit

final class PhotoScanner: Sendable {
    static let shared = PhotoScanner()
    
    private init() {}
    
    /// Fetches all photo assets sorted by creation date descending
    func fetchAllPhotos() -> [PHAsset] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(format: "mediaType == %d", PHAssetMediaType.image.rawValue)
        
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var assets: [PHAsset] = []
        assets.reserveCapacity(result.count)
        result.enumerateObjects { asset, _, _ in
            assets.append(asset)
        }
        return assets
    }
    
    /// Estimates asset file size efficiently
    func estimateAssetSize(asset: PHAsset) -> Int64 {
        let resources = PHAssetResource.assetResources(for: asset)
        if let first = resources.first,
           let size = first.value(forKey: "fileSize") as? Int64, size > 0 {
            return size
        }
        // Fallback: estimate based on pixel dimensions (roughly 2.5 bytes per pixel for compressed JPEG/HEIC)
        let pixels = Int64(asset.pixelWidth * asset.pixelHeight)
        return max(150_000, pixels / 4)
    }
}
