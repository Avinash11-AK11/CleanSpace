import Foundation
import Photos
import UIKit

struct BlurryPhotoItem: Identifiable, Hashable, @unchecked Sendable {
    let photo: PhotoItem
    let sharpnessScore: Double // 0.0 (very blurry) to 1.0 (very sharp)
    
    var id: String { photo.id }
    
    var formattedSharpness: String {
        "\(Int(sharpnessScore * 100))% Sharp"
    }
}

final class BlurDetectionService: @unchecked Sendable {
    static let shared = BlurDetectionService()
    
    private let imageManager = PHImageManager.default()
    
    private init() {}
    
    /// Scans a collection of photo assets and returns those detected as blurry or out of focus
    func detectBlurryPhotos(
        photos: [PHAsset],
        progressHandler: (@Sendable (Double, String) -> Void)? = nil
    ) async -> [BlurryPhotoItem] {
        guard !photos.isEmpty else { return [] }
        
        var blurryItems: [BlurryPhotoItem] = []
        let total = photos.count
        
        for (index, asset) in photos.enumerated() {
            let progress = Double(index) / Double(total)
            progressHandler?(progress, "Scanning photo \(index + 1) of \(total)...")
            
            if let image = await requestThumbnail(for: asset) {
                let variance = computeLaplacianVariance(image: image)
                // Normalize: sharp photos typically have variance > 300, blurry < 100
                let normalizedScore = min(1.0, max(0.0, variance / 400.0))
                
                // Flag as blurry if variance is low
                if normalizedScore < 0.28 {
                    let size = PhotoScanner.shared.estimateAssetSize(asset: asset)
                    let photoItem = PhotoItem(asset: asset, fileSize: size)
                    blurryItems.append(BlurryPhotoItem(photo: photoItem, sharpnessScore: normalizedScore))
                }
            }
        }
        
        progressHandler?(1.0, "Blur scan complete")
        // Sort by blurriest first (lowest sharpness score)
        return blurryItems.sorted { $0.sharpnessScore < $1.sharpnessScore }
    }
    
    /// Requests a small fast thumbnail for edge analysis
    private func requestThumbnail(for asset: PHAsset) async -> UIImage? {
        await withCheckedContinuation { continuation in
            var resumed = false
            let lock = NSLock()
            
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            options.resizeMode = .exact
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true
            
            let targetSize = CGSize(width: 128, height: 128)
            
            imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, _ in
                lock.lock()
                defer { lock.unlock() }
                if !resumed {
                    resumed = true
                    continuation.resume(returning: image)
                }
            }
        }
    }
    
    /// Computes Laplacian variance on grayscale image pixels
    private func computeLaplacianVariance(image: UIImage) -> Double {
        let width = 128
        let height = 128
        
        var rawData = [UInt8](repeating: 0, count: width * height)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ), let cgImage = image.cgImage else {
            return 250.0 // Default to neutral sharpness if context fails
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // 3x3 Laplacian kernel convolution: [0, 1, 0; 1, -4, 1; 0, 1, 0]
        var laplacianValues = [Double]()
        laplacianValues.reserveCapacity((width - 2) * (height - 2))
        
        var sum: Double = 0.0
        
        for y in 1..<(height - 1) {
            for x in 1..<(width - 1) {
                let center = Double(rawData[y * width + x])
                let top = Double(rawData[(y - 1) * width + x])
                let bottom = Double(rawData[(y + 1) * width + x])
                let left = Double(rawData[y * width + (x - 1)])
                let right = Double(rawData[y * width + (x + 1)])
                
                let val = top + bottom + left + right - (4.0 * center)
                laplacianValues.append(val)
                sum += val
            }
        }
        
        guard !laplacianValues.isEmpty else { return 250.0 }
        
        let mean = sum / Double(laplacianValues.count)
        var varianceSum: Double = 0.0
        
        for val in laplacianValues {
            let diff = val - mean
            varianceSum += diff * diff
        }
        
        return varianceSum / Double(laplacianValues.count)
    }
}
