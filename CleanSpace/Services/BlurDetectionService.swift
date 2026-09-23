import Foundation
import Photos
import UIKit
import Vision

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
            
            if let cgImage = await requestAnalysisImage(for: asset) {
                let (isBlurry, score) = analyzeBlur(cgImage: cgImage)
                
                if isBlurry {
                    let size = PhotoScanner.shared.estimateAssetSize(asset: asset)
                    let photoItem = PhotoItem(asset: asset, fileSize: size)
                    blurryItems.append(BlurryPhotoItem(photo: photoItem, sharpnessScore: score))
                }
            }
        }
        
        progressHandler?(1.0, "Blur scan complete")
        // Sort by blurriest first (lowest sharpness score)
        return blurryItems.sorted { $0.sharpnessScore < $1.sharpnessScore }
    }
    
    /// Analyzes image sharpness using Vision face capture quality and multi-block Laplacian variance
    private func analyzeBlur(cgImage: CGImage) -> (isBlurry: Bool, score: Double) {
        // 1. Pass 1: Vision Face Focus & Motion Blur Quality
        let faceRequest = VNDetectFaceCaptureQualityRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        if (try? handler.perform([faceRequest])) != nil,
           let faces = faceRequest.results, !faces.isEmpty {
            let qualities = faces.compactMap { $0.faceCaptureQuality }
            if let minQuality = qualities.min() {
                // Apple's faceCaptureQuality scores holistic quality factoring in focus, motion blur, and illumination (0.0 to 1.0)
                // Faces below 0.45 exhibit noticeable motion blur or soft focus
                if minQuality < 0.45 {
                    return (true, Double(minQuality))
                }
            }
        }
        
        // 2. Pass 2: Local Grid-Based Laplacian & High-Frequency Edge Analysis
        let (gridSharpness, edgeRatio) = computeGridLaplacianMetrics(cgImage: cgImage)
        
        // In sharp photos, the in-focus subject regions produce grid sharpness > 250 and edgeRatio > 0.035
        // In blurry photos (shaky camera, defocus), the 75th percentile block sharpness drops below 120
        let isBlurryByGrid = gridSharpness < 120.0 || (gridSharpness < 155.0 && edgeRatio < 0.028)
        let normalizedScore = min(1.0, max(0.05, gridSharpness / 350.0))
        
        return (isBlurryByGrid, normalizedScore)
    }
    
    /// Requests a high-resolution 512x512 image for accurate edge and facial focus analysis
    private func requestAnalysisImage(for asset: PHAsset) async -> CGImage? {
        await withCheckedContinuation { continuation in
            var resumed = false
            let lock = NSLock()
            
            let options = PHImageRequestOptions()
            options.deliveryMode = .highQualityFormat
            options.resizeMode = .fast
            options.isSynchronous = false
            options.isNetworkAccessAllowed = true
            
            let targetSize = CGSize(width: 512, height: 512)
            
            imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFit, options: options) { image, info in
                lock.lock()
                defer { lock.unlock() }
                
                let isDegraded = (info?[PHImageResultIsDegradedKey] as? Bool) ?? false
                if !isDegraded && !resumed {
                    resumed = true
                    if let img = image {
                        continuation.resume(returning: self.extractCGImage(from: img))
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
            
            // Timeout safety to prevent hanging
            DispatchQueue.global().asyncAfter(deadline: .now() + 2.5) {
                lock.lock()
                defer { lock.unlock() }
                if !resumed {
                    resumed = true
                    continuation.resume(returning: nil)
                }
            }
        }
    }
    
    private func extractCGImage(from image: UIImage) -> CGImage? {
        if let direct = image.cgImage {
            return direct
        }
        if let ci = image.ciImage {
            let ciContext = CIContext()
            return ciContext.createCGImage(ci, from: ci.extent)
        }
        let size = image.size
        guard size.width > 0, size.height > 0 else { return nil }
        let renderer = UIGraphicsImageRenderer(size: size)
        let rendered = renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: size))
        }
        return rendered.cgImage
    }
    
    /// Evaluates sharpness across an 8x8 grid of blocks to prevent isolated lights from skewing overall blur score
    private func computeGridLaplacianMetrics(cgImage: CGImage) -> (p75Variance: Double, edgeRatio: Double) {
        let width = 512
        let height = 512
        
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
        ) else {
            return (250.0, 0.05)
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // 8x8 grid -> 64 blocks of 64x64 pixels each
        let gridSize = 8
        let blockW = width / gridSize
        let blockH = height / gridSize
        
        var blockVariances: [Double] = []
        blockVariances.reserveCapacity(gridSize * gridSize)
        
        var totalEdgeCount = 0
        let totalValidPixels = (width - 2) * (height - 2)
        
        for by in 0..<gridSize {
            for bx in 0..<gridSize {
                let startX = max(1, bx * blockW)
                let endX = min(width - 2, (bx + 1) * blockW)
                let startY = max(1, by * blockH)
                let endY = min(height - 2, (by + 1) * blockH)
                
                var laplacians: [Double] = []
                laplacians.reserveCapacity((endX - startX) * (endY - startY))
                var sum = 0.0
                
                for y in startY..<endY {
                    let yOffset = y * width
                    let yPrev = (y - 1) * width
                    let yNext = (y + 1) * width
                    
                    for x in startX..<endX {
                        let center = Double(rawData[yOffset + x])
                        let top = Double(rawData[yPrev + x])
                        let bottom = Double(rawData[yNext + x])
                        let left = Double(rawData[yOffset + (x - 1)])
                        let right = Double(rawData[yOffset + (x + 1)])
                        
                        let val = top + bottom + left + right - (4.0 * center)
                        laplacians.append(val)
                        sum += val
                        
                        if abs(val) > 22.0 {
                            totalEdgeCount += 1
                        }
                    }
                }
                
                if !laplacians.isEmpty {
                    let mean = sum / Double(laplacians.count)
                    var varSum = 0.0
                    for val in laplacians {
                        let diff = val - mean
                        varSum += diff * diff
                    }
                    blockVariances.append(varSum / Double(laplacians.count))
                }
            }
        }
        
        guard !blockVariances.isEmpty else { return (250.0, 0.05) }
        
        blockVariances.sort()
        // 75th percentile represents the sharpest subject regions (avoiding flat sky at bottom & point lights at top 5%)
        let p75Index = min(blockVariances.count - 1, Int(Double(blockVariances.count) * 0.75))
        let p75 = blockVariances[p75Index]
        let edgeRatio = Double(totalEdgeCount) / Double(max(1, totalValidPixels))
        
        return (p75, edgeRatio)
    }
}
