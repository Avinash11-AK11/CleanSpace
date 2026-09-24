//
//  BlurDetectionService.swift
//  CleanSpace
//
//  Created by Avinash Chavda on 23/09/2026, 10:55 AM.
//  Copyright © 2026 Avinash Chavda. All rights reserved.
//

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
                let (isBlurry, score) = analyzeBlur(cgImage: cgImage, assetId: asset.localIdentifier)
                
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
    
    /// Analyzes image sharpness using Vision face capture quality, face crop analysis, and multi-block Laplacian variance
    private func analyzeBlur(cgImage: CGImage, assetId: String = "") -> (isBlurry: Bool, score: Double) {
        var faceQualityScore: Double? = nil
        var faceCropSharpness: Double? = nil
        
        // 1. Pass 1: Vision Face Focus & Motion Blur Quality
        let faceQualityReq = VNDetectFaceCaptureQualityRequest()
        let faceRectReq = VNDetectFaceRectanglesRequest()
        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        
        if (try? handler.perform([faceQualityReq, faceRectReq])) != nil {
            if let faces = faceQualityReq.results, !faces.isEmpty {
                let qualities = faces.compactMap { $0.faceCaptureQuality }
                if let minQuality = qualities.min() {
                    faceQualityScore = Double(minQuality)
                }
            }
            
            // If faces are found, crop the primary face region and compute local facial sharpness
            if let faceRects = faceRectReq.results, let primaryFace = faceRects.max(by: { $0.boundingBox.width * $0.boundingBox.height < $1.boundingBox.width * $1.boundingBox.height }) {
                let imgW = CGFloat(cgImage.width)
                let imgH = CGFloat(cgImage.height)
                let box = primaryFace.boundingBox
                
                // Convert Vision coordinates (bottom-left origin) to CGImage coordinates (top-left origin)
                let x = max(0, box.origin.x * imgW)
                let y = max(0, (1.0 - box.origin.y - box.size.height) * imgH)
                let w = min(imgW - x, box.size.width * imgW)
                let h = min(imgH - y, box.size.height * imgH)
                
                if w >= 32 && h >= 32, let faceCrop = cgImage.cropping(to: CGRect(x: x, y: y, width: w, height: h)) {
                    let faceMetrics = computeGridLaplacianMetrics(cgImage: faceCrop)
                    faceCropSharpness = faceMetrics.p75Variance
                }
            }
        }
        
        // 2. Pass 2: Local Grid-Based Laplacian & High-Frequency Edge Analysis
        let metrics = computeGridLaplacianMetrics(cgImage: cgImage)
        let gridSharpness = metrics.p75Variance
        let edgeRatio = metrics.edgeRatio
        let medianSharpness = metrics.p50Variance
        let centerSharpness = metrics.centerVariance
        let compositeSharpness = gridSharpness * edgeRatio
        
        // Evaluate Blurry criteria:
        var isBlurry = false
        var reason = ""
        
        // Face Quality criteria:
        if let fq = faceQualityScore, fq < 0.58 {
            isBlurry = true
            reason = "faceQuality (\(String(format: "%.2f", fq)) < 0.58)"
        } else if let fcs = faceCropSharpness, fcs < 185.0 {
            isBlurry = true
            reason = "faceCropSharpness (\(String(format: "%.1f", fcs)) < 185.0)"
        }
        
        // Grid & Edge Sharpness criteria:
        if !isBlurry {
            if compositeSharpness < 14.8 {
                isBlurry = true
                reason = "compositeSharpness (\(String(format: "%.2f", compositeSharpness)) < 14.8)"
            } else if gridSharpness < 180.0 {
                isBlurry = true
                reason = "gridSharpness p75 (\(String(format: "%.1f", gridSharpness)) < 180.0)"
            } else if gridSharpness < 275.0 && edgeRatio < 0.050 {
                isBlurry = true
                reason = "p75 < 275 & edgeRatio < 0.050 (p75=\(String(format: "%.1f", gridSharpness)), ratio=\(String(format: "%.4f", edgeRatio)))"
            } else if centerSharpness < 150.0 && medianSharpness < 95.0 {
                isBlurry = true
                reason = "center < 150 & median < 95 (center=\(String(format: "%.1f", centerSharpness)), med=\(String(format: "%.1f", medianSharpness)))"
            } else if edgeRatio < 0.022 {
                isBlurry = true
                reason = "edgeRatio (\(String(format: "%.4f", edgeRatio)) < 0.022)"
            }
        }
        
        let normalizedScore: Double
        if let fq = faceQualityScore, isBlurry {
            normalizedScore = min(0.48, max(0.05, fq))
        } else {
            normalizedScore = min(1.0, max(0.05, compositeSharpness / 30.0))
        }
        
        return (isBlurry, normalizedScore)
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
    
    private struct GridMetrics {
        let p75Variance: Double
        let p50Variance: Double
        let centerVariance: Double
        let edgeRatio: Double
    }
    
    /// Evaluates sharpness across an 8x8 grid of blocks to prevent isolated lights from skewing overall blur score
    private func computeGridLaplacianMetrics(cgImage: CGImage) -> GridMetrics {
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
            return GridMetrics(p75Variance: 250.0, p50Variance: 150.0, centerVariance: 200.0, edgeRatio: 0.05)
        }
        
        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))
        
        // 8x8 grid -> 64 blocks of 64x64 pixels each
        let gridSize = 8
        let blockW = width / gridSize
        let blockH = height / gridSize
        
        var blockVariances: [Double] = []
        blockVariances.reserveCapacity(gridSize * gridSize)
        var centerVariances: [Double] = []
        centerVariances.reserveCapacity(16)
        
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
                    let blockVar = varSum / Double(laplacians.count)
                    blockVariances.append(blockVar)
                    
                    // Central 4x4 region (rows 2..5, cols 2..5)
                    if bx >= 2 && bx <= 5 && by >= 2 && by <= 5 {
                        centerVariances.append(blockVar)
                    }
                }
            }
        }
        
        guard !blockVariances.isEmpty else {
            return GridMetrics(p75Variance: 250.0, p50Variance: 150.0, centerVariance: 200.0, edgeRatio: 0.05)
        }
        
        blockVariances.sort()
        let p75Index = min(blockVariances.count - 1, Int(Double(blockVariances.count) * 0.75))
        let p50Index = min(blockVariances.count - 1, Int(Double(blockVariances.count) * 0.50))
        let p75 = blockVariances[p75Index]
        let p50 = blockVariances[p50Index]
        
        let centerAvg = centerVariances.isEmpty ? p50 : (centerVariances.reduce(0, +) / Double(centerVariances.count))
        let edgeRatio = Double(totalEdgeCount) / Double(max(1, totalValidPixels))
        
        return GridMetrics(p75Variance: p75, p50Variance: p50, centerVariance: centerAvg, edgeRatio: edgeRatio)
    }
}
