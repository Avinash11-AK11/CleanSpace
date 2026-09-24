//
//  VideoCompressionService.swift
//  CleanSpace
//
//  Created by Avinash Chavda on 23/09/2026, 10:55 AM.
//  Copyright © 2026 Avinash Chavda. All rights reserved.
//

import Foundation
import Photos
import AVFoundation

enum CompressionPreset: String, CaseIterable, Identifiable, Sendable {
    case high = "High Quality"
    case medium = "Balanced (Recommended)"
    case low = "Maximum Savings"
    
    var id: String { rawValue }
    
    func title(for video: VideoItem) -> String {
        let maxDim = max(video.pixelWidth, video.pixelHeight)
        switch self {
        case .high:
            if maxDim >= 2160 { return "1080p Full HD" }
            if maxDim >= 1080 { return "1080p High Quality" }
            if maxDim >= 720 { return "720p High Quality" }
            return "SD High Quality"
        case .medium:
            if maxDim >= 1080 { return "720p Balanced (Recommended)" }
            if maxDim >= 720 { return "540p Balanced (Recommended)" }
            return "SD Balanced (Recommended)"
        case .low:
            if maxDim >= 1080 { return "540p Maximum Savings" }
            if maxDim >= 720 { return "480p Maximum Savings" }
            return "Compact SD Savings"
        }
    }
    
    func subtitle(for video: VideoItem) -> String {
        let maxDim = max(video.pixelWidth, video.pixelHeight)
        switch self {
        case .high:
            if maxDim >= 2160 { return "Downscaled from 4K • Sharp HD detail" }
            if maxDim >= 1080 { return "Retains 1080p HD • Optimized bitrate" }
            if maxDim >= 720 { return "Retains 720p HD • Optimized bitrate" }
            return "Preserves source resolution • Optimized size"
        case .medium:
            if maxDim >= 1080 { return "Standard 720p HD • Ideal balance of clarity & size" }
            if maxDim >= 720 { return "Downscaled to 540p • Great space savings" }
            return "Balanced compression for smaller storage"
        case .low:
            if maxDim >= 1080 { return "Compact 540p SD • Highest storage reclaimed" }
            if maxDim >= 720 { return "Compact 480p SD • Maximum storage reclaimed" }
            return "Highest compression for minimum file size"
        }
    }
    
    func badge(for video: VideoItem) -> String {
        let maxDim = max(video.pixelWidth, video.pixelHeight)
        switch self {
        case .high:
            return maxDim >= 1080 ? "1080p" : (maxDim >= 720 ? "720p" : "SD")
        case .medium:
            return maxDim >= 1080 ? "720p" : (maxDim >= 720 ? "540p" : "SD")
        case .low:
            return maxDim >= 1080 ? "540p" : (maxDim >= 720 ? "480p" : "SD")
        }
    }
    
    func preferredPresetNames(assetWidth: Int = 1920, assetHeight: Int = 1080) -> [String] {
        let maxDim = max(assetWidth, assetHeight)
        switch self {
        case .high:
            #if targetEnvironment(simulator)
            if maxDim >= 1080 {
                return [
                    AVAssetExportPreset1920x1080,
                    AVAssetExportPreset1280x720,
                    AVAssetExportPresetMediumQuality
                ]
            } else if maxDim >= 720 {
                return [
                    AVAssetExportPreset1280x720,
                    AVAssetExportPresetMediumQuality
                ]
            } else {
                return [
                    AVAssetExportPresetMediumQuality,
                    AVAssetExportPreset960x540
                ]
            }
            #else
            if maxDim >= 1080 {
                return [
                    AVAssetExportPresetHEVC1920x1080,
                    AVAssetExportPreset1920x1080,
                    AVAssetExportPreset1280x720,
                    AVAssetExportPresetMediumQuality
                ]
            } else if maxDim >= 720 {
                return [
                    AVAssetExportPresetHEVC1280x720,
                    AVAssetExportPreset1280x720,
                    AVAssetExportPresetMediumQuality
                ]
            } else {
                return [
                    AVAssetExportPresetMediumQuality,
                    AVAssetExportPreset960x540
                ]
            }
            #endif
            
        case .medium:
            #if targetEnvironment(simulator)
            if maxDim >= 1080 {
                return [
                    AVAssetExportPreset1280x720,
                    AVAssetExportPresetMediumQuality,
                    AVAssetExportPreset960x540
                ]
            } else if maxDim >= 720 {
                return [
                    AVAssetExportPreset960x540,
                    AVAssetExportPresetMediumQuality
                ]
            } else {
                return [
                    AVAssetExportPresetLowQuality,
                    AVAssetExportPreset640x480
                ]
            }
            #else
            if maxDim >= 1080 {
                return [
                    AVAssetExportPresetHEVC1280x720,
                    AVAssetExportPreset1280x720,
                    AVAssetExportPresetMediumQuality,
                    AVAssetExportPreset960x540
                ]
            } else if maxDim >= 720 {
                return [
                    AVAssetExportPresetHEVC960x540,
                    AVAssetExportPreset960x540,
                    AVAssetExportPresetMediumQuality
                ]
            } else {
                return [
                    AVAssetExportPresetLowQuality,
                    AVAssetExportPreset640x480
                ]
            }
            #endif
            
        case .low:
            if maxDim >= 1080 {
                return [
                    AVAssetExportPreset960x540,
                    AVAssetExportPresetLowQuality,
                    AVAssetExportPresetMediumQuality
                ]
            } else if maxDim >= 720 {
                return [
                    AVAssetExportPreset640x480,
                    AVAssetExportPresetLowQuality,
                    AVAssetExportPreset960x540
                ]
            } else {
                return [
                    AVAssetExportPresetLowQuality
                ]
            }
        }
    }
    
    var preferredPresetNames: [String] {
        preferredPresetNames(assetWidth: 1920, assetHeight: 1080)
    }
    
    var reductionFactor: Double {
        switch self {
        case .high:
            return 0.45 // ~45% average savings
        case .medium:
            return 0.70 // ~70% average savings
        case .low:
            return 0.88 // ~88% average savings
        }
    }
    
    var resolutionLabel: String {
        switch self {
        case .high: return "1080p"
        case .medium: return "720p"
        case .low: return "540p"
        }
    }
}

final class VideoCompressionService: @unchecked Sendable {
    static let shared = VideoCompressionService()
    
    private init() {}
    
    /// Estimates compressed file size for a given preset, video duration, and resolution
    func estimateCompressedSize(
        originalBytes: Int64,
        duration: Double,
        preset: CompressionPreset,
        videoWidth: Int = 1920,
        videoHeight: Int = 1080
    ) -> Int64 {
        guard originalBytes > 0 else { return 0 }
        let maxDim = max(videoWidth, videoHeight)
        let effectiveDuration = duration > 0 ? duration : 30.0
        
        let targetRate: Double
        let minReduction: Double
        let maxReduction: Double
        
        switch preset {
        case .high:
            if maxDim >= 1080 {
                targetRate = 1_000_000 // ~8 Mbps
            } else if maxDim >= 720 {
                targetRate = 500_000   // ~4 Mbps
            } else {
                targetRate = 280_000   // ~2.2 Mbps
            }
            minReduction = 0.25
            maxReduction = 0.55
            
        case .medium:
            if maxDim >= 1080 {
                targetRate = 500_000   // ~4 Mbps (720p HD)
            } else if maxDim >= 720 {
                targetRate = 260_000   // ~2.1 Mbps (540p)
            } else {
                targetRate = 160_000   // ~1.3 Mbps
            }
            minReduction = 0.50
            maxReduction = 0.78
            
        case .low:
            if maxDim >= 1080 {
                targetRate = 220_000   // ~1.8 Mbps (540p SD)
            } else if maxDim >= 720 {
                targetRate = 140_000   // ~1.1 Mbps (480p)
            } else {
                targetRate = 90_000    // ~0.7 Mbps
            }
            minReduction = 0.75
            maxReduction = 0.92
        }
        
        let bitrateBased = Int64(effectiveDuration * targetRate)
        let minAllowedSize = Int64(Double(originalBytes) * (1.0 - maxReduction))
        let maxAllowedSize = Int64(Double(originalBytes) * (1.0 - minReduction))
        
        let clamped = min(max(bitrateBased, minAllowedSize), maxAllowedSize)
        return max(200_000, min(clamped, Int64(Double(originalBytes) * 0.82)))
    }
    
    /// Compresses a video asset with real-time progress callbacks and guaranteed size reduction
    func compressVideo(
        asset: PHAsset,
        preset: CompressionPreset,
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) async throws -> URL {
        let avAsset: AVAsset = try await withCheckedThrowingContinuation { continuation in
            var hasResumed = false
            let lock = NSLock()
            
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, info in
                lock.lock()
                defer { lock.unlock() }
                
                guard !hasResumed else { return }
                
                if let isDegraded = info?[PHImageResultIsDegradedKey] as? Bool, isDegraded {
                    return
                }
                
                if let error = info?[PHImageErrorKey] as? Error {
                    hasResumed = true
                    continuation.resume(throwing: error)
                } else if let avAsset = avAsset {
                    hasResumed = true
                    continuation.resume(returning: avAsset)
                } else {
                    hasResumed = true
                    continuation.resume(throwing: NSError(domain: "CleanSpaceVideoCompression", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load video asset"]))
                }
            }
        }
        
        let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: avAsset)
        
        // Try preferred presets in order with automatic fallback
        var lastError: Error?
        var outputURL: URL?
        
        let candidates = preset.preferredPresetNames(assetWidth: asset.pixelWidth, assetHeight: asset.pixelHeight)
        for candidate in candidates {
            guard compatiblePresets.contains(candidate) else { continue }
            
            do {
                print("CleanSpace: Exporting video with preset: \(candidate)")
                let url = try await runExportSession(avAsset: avAsset, presetName: candidate, progressHandler: progressHandler)
                outputURL = url
                break
            } catch {
                print("CleanSpace: Export with \(candidate) failed (\(error.localizedDescription)). Trying next preset...")
                lastError = error
            }
        }
        
        guard let finalURL = outputURL else {
            throw lastError ?? NSError(domain: "CleanSpaceVideoCompression", code: -2, userInfo: [NSLocalizedDescriptionKey: "No compatible export preset could complete compression."])
        }
        
        // Check output size vs original size
        let resources = PHAssetResource.assetResources(for: asset)
        let originalBytes = (resources.first?.value(forKey: "fileSize") as? Int64) ?? 0
        let exportedBytes = (try? FileManager.default.attributesOfItem(atPath: finalURL.path)[.size] as? Int64) ?? 0
        
        // If output size is >= original size, re-export using a smaller preset to guarantee savings!
        if originalBytes > 0 && exportedBytes >= originalBytes {
            let fallbackPresets = [
                AVAssetExportPreset1280x720,
                AVAssetExportPresetMediumQuality,
                AVAssetExportPreset960x540
            ]
            for fallback in fallbackPresets {
                if compatiblePresets.contains(fallback) {
                    try? FileManager.default.removeItem(at: finalURL)
                    if let smallerURL = try? await runExportSession(avAsset: avAsset, presetName: fallback, progressHandler: nil) {
                        return smallerURL
                    }
                }
            }
        }
        
        return finalURL
    }
    
    private func runExportSession(
        avAsset: AVAsset,
        presetName: String,
        progressHandler: (@Sendable (Double) -> Void)?
    ) async throws -> URL {
        guard let exportSession = AVAssetExportSession(asset: avAsset, presetName: presetName) else {
            throw NSError(domain: "CleanSpaceVideoCompression", code: -3, userInfo: [NSLocalizedDescriptionKey: "Preset not supported: \(presetName)"])
        }
        
        let supportedTypes = exportSession.supportedFileTypes
        let fileType: AVFileType
        if supportedTypes.contains(.mp4) {
            fileType = .mp4
        } else if supportedTypes.contains(.mov) {
            fileType = .mov
        } else {
            fileType = supportedTypes.first ?? .mp4
        }
        
        let ext = (fileType == .mov) ? "mov" : "mp4"
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("compressed_\(UUID().uuidString)")
            .appendingPathExtension(ext)
        
        try? FileManager.default.removeItem(at: outputURL)
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = fileType
        #if !targetEnvironment(simulator)
        exportSession.shouldOptimizeForNetworkUse = true
        #endif
        
        return try await withCheckedThrowingContinuation { continuation in
            let lock = NSLock()
            var hasCompleted = false
            
            @Sendable func finish(with result: Result<URL, Error>) {
                lock.lock()
                defer { lock.unlock() }
                guard !hasCompleted else { return }
                hasCompleted = true
                switch result {
                case .success(let url):
                    continuation.resume(returning: url)
                case .failure(let err):
                    continuation.resume(throwing: err)
                }
            }
            
            // Watchdog & Progress polling task
            let progressTask = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(nanoseconds: 120_000_000) // 120ms
                    
                    let s = exportSession.status
                    let p = Double(exportSession.progress)
                    
                    if s == .exporting || s == .waiting {
                        progressHandler?(max(0.08, min(0.98, p)))
                    } else if s == .completed {
                        progressHandler?(1.0)
                        finish(with: .success(outputURL))
                        break
                    } else if s == .failed {
                        let err = exportSession.error ?? NSError(domain: "CleanSpaceVideoCompression", code: -4, userInfo: [NSLocalizedDescriptionKey: "Video export session failed."])
                        finish(with: .failure(err))
                        break
                    } else if s == .cancelled {
                        finish(with: .failure(NSError(domain: "CleanSpaceVideoCompression", code: -5, userInfo: [NSLocalizedDescriptionKey: "Video export was cancelled."])))
                        break
                    }
                }
            }
            
            exportSession.exportAsynchronously {
                progressTask.cancel()
                let s = exportSession.status
                if s == .completed {
                    progressHandler?(1.0)
                    finish(with: .success(outputURL))
                } else if s == .failed {
                    let err = exportSession.error ?? NSError(domain: "CleanSpaceVideoCompression", code: -4, userInfo: [NSLocalizedDescriptionKey: "Video export session failed."])
                    finish(with: .failure(err))
                } else if s == .cancelled {
                    finish(with: .failure(NSError(domain: "CleanSpaceVideoCompression", code: -5, userInfo: [NSLocalizedDescriptionKey: "Video export was cancelled."])))
                }
            }
        }
    }
    
    /// Saves the compressed video to the user's Photos library and optionally deletes the original uncompressed video.
    /// Returns the local identifier of the newly created compressed asset, or nil if created without tracked identifier.
    func saveCompressedVideo(
        fileURL: URL,
        originalAsset: PHAsset?,
        deleteOriginal: Bool
    ) async throws -> (newAssetId: String?, originalDeleted: Bool) {
        var placeholderId: String? = nil
        
        // 1. Save new compressed video FIRST (independent transaction)
        try await PHPhotoLibrary.shared().performChanges {
            let request = PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: fileURL)
            if let placeholder = request?.placeholderForCreatedAsset {
                placeholderId = placeholder.localIdentifier
            }
        }
        
        // Clean up temporary local file now that it is saved
        try? FileManager.default.removeItem(at: fileURL)
        
        // 2. Optionally delete original in a SEPARATE transaction so a "Don't Allow" does NOT fail the save
        var originalDeleted = false
        if deleteOriginal, let original = originalAsset {
            do {
                try await CleanupService.shared.deleteAssets(assets: [original])
                originalDeleted = true
            } catch {
                print("CleanSpace: User chose 'Don't Allow' or deletion was cancelled: \(error). New compressed video remains saved.")
                originalDeleted = false
            }
        }
        
        return (placeholderId, originalDeleted)
    }
}
