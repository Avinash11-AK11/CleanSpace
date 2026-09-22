import Foundation
import Photos
import Vision
import UIKit

final class PhotoSimilarityService: @unchecked Sendable {
    static let shared = PhotoSimilarityService()
    
    private let imageManager = PHCachingImageManager.default()
    
    private init() {}
    
    /// Finds groups of similar or duplicate photos.
    /// Uses a robust multi-strategy approach:
    /// Strategy 1: Burst / Time-proximity clustering (photos taken within 60s)
    /// Strategy 2: Dimension clustering (matching aspect ratio & resolution)
    /// Strategy 3: Visual perceptual similarity using CGContext bitmap sampling
    func findSimilarGroups(
        photos: [PHAsset],
        progressHandler: (@Sendable (Double, String) -> Void)? = nil
    ) async -> [PhotoGroup] {
        guard photos.count > 1 else { return [] }
        
        progressHandler?(0.05, "Sorting and bucketing candidates...")
        
        // Pass 1: Build candidate clusters
        var candidateClusters: [[PHAsset]] = []
        
        // Cluster by time window (bursts or close shots within 60s)
        let sortedByDate = photos.sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
        var timeCluster: [PHAsset] = []
        for photo in sortedByDate {
            guard let currentDate = photo.creationDate else { continue }
            if let last = timeCluster.last, let lastDate = last.creationDate {
                let interval = abs(currentDate.timeIntervalSince(lastDate))
                if interval <= 60.0 {
                    timeCluster.append(photo)
                } else {
                    if timeCluster.count >= 2 {
                        candidateClusters.append(timeCluster)
                    }
                    timeCluster = [photo]
                }
            } else {
                timeCluster = [photo]
            }
        }
        if timeCluster.count >= 2 {
            candidateClusters.append(timeCluster)
        }
        
        // Also cluster photos with identical aspect ratios & resolutions (e.g. imported or duplicate files)
        var dimensionBuckets: [String: [PHAsset]] = [:]
        for photo in photos {
            let key = "\(photo.pixelWidth)x\(photo.pixelHeight)"
            dimensionBuckets[key, default: []].append(photo)
        }
        for (_, bucket) in dimensionBuckets where bucket.count >= 2 {
            candidateClusters.append(bucket)
        }
        
        // If library has 50 or fewer photos (typical on simulator or small test albums), also compare all
        if photos.count <= 50 {
            candidateClusters.append(photos)
        }
        
        // Deduplicate clusters to avoid redundant work
        var seenClusterSets = Set<Set<String>>()
        var uniqueClusters: [[PHAsset]] = []
        for cluster in candidateClusters {
            let idSet = Set(cluster.map { $0.localIdentifier })
            if !seenClusterSets.contains(idSet) {
                seenClusterSets.insert(idSet)
                uniqueClusters.append(cluster)
            }
        }
        
        let totalClusters = uniqueClusters.count
        guard totalClusters > 0 else {
            progressHandler?(1.0, "Scan complete")
            return []
        }
        
        var resultGroups: [PhotoGroup] = []
        var groupedAssetIds = Set<String>()
        
        let targetSize = CGSize(width: 100, height: 100)
        let options = PHImageRequestOptions()
        options.isSynchronous = true
        options.deliveryMode = .fastFormat
        options.resizeMode = .fast
        options.isNetworkAccessAllowed = true
        
        var processedCount = 0
        
        for cluster in uniqueClusters {
            processedCount += 1
            let progress = 0.1 + (Double(processedCount) / Double(totalClusters)) * 0.85
            progressHandler?(progress, "Analyzing photos (\(processedCount)/\(totalClusters))...")
            
            let activeCluster = cluster.filter { !groupedAssetIds.contains($0.localIdentifier) }
            guard activeCluster.count >= 2 else { continue }
            
            // Extract lightweight feature fingerprints for this cluster
            var items: [(asset: PHAsset, fingerprint: [UInt8], score: Double)] = []
            
            for asset in activeCluster {
                if let image = self.loadThumbnail(for: asset, targetSize: targetSize, options: options) {
                    let fingerprint = self.computePerceptualHash(from: image)
                    let score = self.calculateBestScore(asset: asset)
                    items.append((asset, fingerprint, score))
                }
            }
            
            guard items.count >= 2 else { continue }
            
            var visited = Set<Int>()
            for i in 0..<items.count {
                if visited.contains(i) { continue }
                var groupAssets: [PHAsset] = [items[i].asset]
                var bestAsset = items[i].asset
                var bestScore = items[i].score
                visited.insert(i)
                
                for j in (i + 1)..<items.count {
                    if visited.contains(j) { continue }
                    
                    let similarity = self.compareFingerprints(items[i].fingerprint, items[j].fingerprint)
                    // 0.82 threshold accommodates minor compression, crop, or lighting differences
                    if similarity >= 0.82 {
                        visited.insert(j)
                        groupAssets.append(items[j].asset)
                        if items[j].score > bestScore {
                            bestScore = items[j].score
                            bestAsset = items[j].asset
                        }
                    }
                }
                
                if groupAssets.count >= 2 {
                    for a in groupAssets { groupedAssetIds.insert(a.localIdentifier) }
                    let photoItems = groupAssets.map { asset in
                        PhotoItem(asset: asset, fileSize: PhotoScanner.shared.estimateAssetSize(asset: asset))
                    }
                    let group = PhotoGroup(
                        photos: photoItems,
                        recommendedBestId: bestAsset.localIdentifier,
                        similarityScore: 0.94
                    )
                    resultGroups.append(group)
                }
            }
        }
        
        progressHandler?(1.0, "Found \(resultGroups.count) groups")
        return resultGroups
    }
    
    private func loadThumbnail(for asset: PHAsset, targetSize: CGSize, options: PHImageRequestOptions) -> UIImage? {
        var result: UIImage?
        imageManager.requestImage(for: asset, targetSize: targetSize, contentMode: .aspectFill, options: options) { image, _ in
            result = image
        }
        return result
    }
    
    /// Generates a reliable 16x16 grayscale perceptual vector using direct CoreGraphics bitmap context
    private func computePerceptualHash(from image: UIImage) -> [UInt8] {
        guard let cgImage = image.cgImage else {
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16))
            let downsampled = renderer.image { _ in
                image.draw(in: CGRect(x: 0, y: 0, width: 16, height: 16))
            }
            if let renderedCG = downsampled.cgImage {
                return extractGrayscaleBytes(from: renderedCG)
            }
            return [UInt8](repeating: 128, count: 256)
        }
        return extractGrayscaleBytes(from: cgImage)
    }
    
    private func extractGrayscaleBytes(from cgImage: CGImage) -> [UInt8] {
        let width = 16
        let height = 16
        var rawData = [UInt8](repeating: 0, count: width * height * 4)
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGImageAlphaInfo.premultipliedLast.rawValue | CGBitmapInfo.byteOrder32Big.rawValue
        
        guard let context = CGContext(
            data: &rawData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: width * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo
        ) else {
            return [UInt8](repeating: 128, count: 256)
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var grayscale: [UInt8] = []
        grayscale.reserveCapacity(256)
        for i in 0..<256 {
            let offset = i * 4
            let r = UInt32(rawData[offset])
            let g = UInt32(rawData[offset + 1])
            let b = UInt32(rawData[offset + 2])
            let grayValue = (r * 299 + g * 587 + b * 114) / 1000
            grayscale.append(UInt8(truncatingIfNeeded: grayValue))
        }
        return grayscale
    }
    
    /// Compares two 16x16 perceptual hashes, returning similarity 0.0 ... 1.0
    private func compareFingerprints(_ a: [UInt8], _ b: [UInt8]) -> Double {
        guard a.count == b.count, !a.isEmpty else { return 0.0 }
        var totalDiff: Double = 0
        for i in 0..<a.count {
            totalDiff += abs(Double(a[i]) - Double(b[i]))
        }
        let maxDiff = Double(a.count * 255)
        return max(0.0, 1.0 - (totalDiff / maxDiff))
    }
    
    /// Scores photo quality: resolution + favorite + recency
    private func calculateBestScore(asset: PHAsset) -> Double {
        var score: Double = 0.0
        let pixels = Double(asset.pixelWidth * asset.pixelHeight)
        score += min(pixels / 12_000_000.0, 2.0) * 10.0
        if asset.isFavorite { score += 5.0 }
        if let date = asset.creationDate {
            score += date.timeIntervalSince1970 / 1_000_000_000.0
        }
        return score
    }
}
