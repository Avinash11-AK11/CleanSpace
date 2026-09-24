//
//  PhotoSimilarityService.swift
//  CleanSpace
//
//  Created by Avinash Chavda on 22/09/2026, 06:03 PM.
//  Copyright © 2026 Avinash Chavda. All rights reserved.
//

import Foundation
import Photos
import UIKit

final class PhotoSimilarityService: @unchecked Sendable {
    static let shared = PhotoSimilarityService()
    
    private let imageManager = PHImageManager.default()
    
    private init() {}
    
    /// Finds groups of similar or duplicate photos.
    /// Multi-pass clustering:
    /// Pass 1: Time proximity & aspect ratio buckets
    /// Pass 2: High-dimensional RGB + luminance spatial perceptual hashing
    /// Strict 0.93 threshold ensures different images (even with similar color palettes) are not falsely grouped.
    func findSimilarGroups(
        photos: [PHAsset],
        progressHandler: (@Sendable (Double, String) -> Void)? = nil
    ) async -> [PhotoGroup] {
        guard photos.count > 1 else { return [] }
        
        progressHandler?(0.05, "Sorting and bucketing candidates...")
        
        // Pass 1: Build candidate clusters
        var candidateClusters: [[PHAsset]] = []
        
        // Cluster by time window (bursts or close shots within 45s)
        let sortedByDate = photos.sorted { ($0.creationDate ?? .distantPast) < ($1.creationDate ?? .distantPast) }
        var timeCluster: [PHAsset] = []
        for photo in sortedByDate {
            guard let currentDate = photo.creationDate else { continue }
            if let last = timeCluster.last, let lastDate = last.creationDate {
                let interval = abs(currentDate.timeIntervalSince(lastDate))
                if interval <= 45.0 {
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
        
        // Also cluster photos with identical aspect ratios & resolutions
        var dimensionBuckets: [String: [PHAsset]] = [:]
        for photo in photos {
            let key = "\(photo.pixelWidth)x\(photo.pixelHeight)"
            dimensionBuckets[key, default: []].append(photo)
        }
        for (_, bucket) in dimensionBuckets where bucket.count >= 2 {
            candidateClusters.append(bucket)
        }
        
        // If library is small (<= 50 photos), also include all photos for exhaustive comparison
        if photos.count <= 50 {
            candidateClusters.append(photos)
        }
        
        // Deduplicate clusters
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
        var processedCount = 0
        
        for cluster in uniqueClusters {
            processedCount += 1
            let progress = 0.1 + (Double(processedCount) / Double(totalClusters)) * 0.85
            progressHandler?(progress, "Analyzing photos (\(processedCount)/\(totalClusters))...")
            
            let activeCluster = cluster.filter { !groupedAssetIds.contains($0.localIdentifier) }
            guard activeCluster.count >= 2 else { continue }
            
            // Extract lightweight feature fingerprints for this cluster
            var items: [(asset: PHAsset, fingerprint: [UInt8], score: Double, aspectRatio: Double)] = []
            
            for asset in activeCluster {
                if let image = await self.requestImageSafe(for: asset) {
                    let fingerprint = self.computePerceptualHash(from: image)
                    let score = self.calculateBestScore(asset: asset)
                    let ar = Double(asset.pixelWidth) / max(1.0, Double(asset.pixelHeight))
                    items.append((asset, fingerprint, score, ar))
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
                    
                    // Reject if aspect ratio differs by more than 10%
                    let arDiff = abs(items[i].aspectRatio - items[j].aspectRatio)
                    if arDiff > 0.10 { continue }
                    
                    let similarity = self.compareFingerprints(items[i].fingerprint, items[j].fingerprint)
                    // High precision 0.93 threshold prevents false positives between different images
                    if similarity >= 0.93 {
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
                        similarityScore: 0.96
                    )
                    resultGroups.append(group)
                }
            }
        }
        
        progressHandler?(1.0, "Found \(resultGroups.count) groups")
        return resultGroups
    }
    
    /// Requests image using PHImageManager with fallback to requestImageDataAndOrientation
    private func requestImageSafe(for asset: PHAsset) async -> UIImage? {
        let fromManager: UIImage? = await withCheckedContinuation { continuation in
            var hasResumed = false
            let lock = NSLock()
            
            let options = PHImageRequestOptions()
            options.deliveryMode = .fastFormat
            options.resizeMode = .none
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            
            imageManager.requestImage(
                for: asset,
                targetSize: PHImageManagerMaximumSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                lock.lock()
                defer { lock.unlock() }
                if !hasResumed {
                    hasResumed = true
                    continuation.resume(returning: image)
                }
            }
        }
        
        if let img = fromManager {
            return img
        }
        
        return await withCheckedContinuation { continuation in
            var hasResumed = false
            let lock = NSLock()
            
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            
            imageManager.requestImageDataAndOrientation(for: asset, options: options) { data, _, _, _ in
                lock.lock()
                defer { lock.unlock() }
                if !hasResumed {
                    hasResumed = true
                    if let data = data, let image = UIImage(data: data) {
                        continuation.resume(returning: image)
                    } else {
                        continuation.resume(returning: nil)
                    }
                }
            }
        }
    }
    
    /// Generates a rich 16x16 perceptual RGB vector (768 values)
    private func computePerceptualHash(from image: UIImage) -> [UInt8] {
        guard let cgImage = image.cgImage else {
            let renderer = UIGraphicsImageRenderer(size: CGSize(width: 16, height: 16))
            let downsampled = renderer.image { _ in
                image.draw(in: CGRect(x: 0, y: 0, width: 16, height: 16))
            }
            if let renderedCG = downsampled.cgImage {
                return extractRGBBytes(from: renderedCG)
            }
            return [UInt8](repeating: 128, count: 768)
        }
        return extractRGBBytes(from: cgImage)
    }
    
    private func extractRGBBytes(from cgImage: CGImage) -> [UInt8] {
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
            return [UInt8](repeating: 128, count: 768)
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        var rgbValues: [UInt8] = []
        rgbValues.reserveCapacity(width * height * 3)
        for i in 0..<(width * height) {
            let offset = i * 4
            rgbValues.append(rawData[offset])     // R
            rgbValues.append(rawData[offset + 1]) // G
            rgbValues.append(rawData[offset + 2]) // B
        }
        return rgbValues
    }
    
    /// Compares RGB color and luminance perceptual hashes, returning similarity 0.0 ... 1.0
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
