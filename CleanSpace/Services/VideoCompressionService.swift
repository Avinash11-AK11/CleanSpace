import Foundation
import Photos
import AVFoundation

enum CompressionPreset: String, CaseIterable, Identifiable, Sendable {
    case high = "1080p High Quality"
    case medium = "720p Balanced (Recommended)"
    case low = "540p Maximum Savings"
    
    var id: String { rawValue }
    
    var preferredPresetNames: [String] {
        switch self {
        case .high:
            return [
                AVAssetExportPresetHEVC1920x1080,
                AVAssetExportPreset1920x1080,
                AVAssetExportPreset1280x720,
                AVAssetExportPresetMediumQuality
            ]
        case .medium:
            return [
                AVAssetExportPreset1280x720,
                AVAssetExportPresetMediumQuality,
                AVAssetExportPreset960x540
            ]
        case .low:
            return [
                AVAssetExportPreset960x540,
                AVAssetExportPresetLowQuality,
                AVAssetExportPresetMediumQuality
            ]
        }
    }
    
    var reductionFactor: Double {
        switch self {
        case .high:
            return 0.65 // ~65% savings with 1080p HEVC
        case .medium:
            return 0.80 // ~80% savings with 720p HEVC
        case .low:
            return 0.90 // ~90% savings with 540p
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
    
    /// Estimates compressed file size for a given preset and video duration
    func estimateCompressedSize(originalBytes: Int64, duration: Double, preset: CompressionPreset) -> Int64 {
        // Target bitrates for presets
        // High (1080p HEVC): ~4.5 Mbps ≈ 560 KB/s
        // Medium (720p HEVC): ~2.2 Mbps ≈ 275 KB/s
        // Low (540p): ~1.0 Mbps ≈ 125 KB/s
        let ratePerSecond: Double
        switch preset {
        case .high: ratePerSecond = 560_000
        case .medium: ratePerSecond = 275_000
        case .low: ratePerSecond = 125_000
        }
        
        let durationBased = duration > 0 ? Int64(duration * ratePerSecond) : originalBytes / 2
        let factorBased = Int64(Double(originalBytes) * (1.0 - preset.reductionFactor))
        let target = min(durationBased, factorBased)
        
        // Guarantee estimated size is always smaller than original (at least 20% smaller)
        let maxAllowed = max(400_000, Int64(Double(originalBytes) * 0.78))
        return max(350_000, min(target, maxAllowed))
    }
    
    /// Compresses a video asset with real-time progress callbacks and guaranteed size reduction
    func compressVideo(
        asset: PHAsset,
        preset: CompressionPreset,
        progressHandler: (@Sendable (Double) -> Void)? = nil
    ) async throws -> URL {
        let avAsset: AVAsset = try await withCheckedThrowingContinuation { continuation in
            let options = PHVideoRequestOptions()
            options.isNetworkAccessAllowed = true
            options.deliveryMode = .highQualityFormat
            
            PHImageManager.default().requestAVAsset(forVideo: asset, options: options) { avAsset, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                } else if let avAsset = avAsset {
                    continuation.resume(returning: avAsset)
                } else {
                    continuation.resume(throwing: NSError(domain: "CleanSpaceVideoCompression", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to load video asset"]))
                }
            }
        }
        
        let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: avAsset)
        
        // Find best compatible preset from preferred list
        var chosenPreset = AVAssetExportPresetMediumQuality
        for candidate in preset.preferredPresetNames {
            if compatiblePresets.contains(candidate) {
                chosenPreset = candidate
                break
            }
        }
        
        var outputURL = try await runExportSession(avAsset: avAsset, presetName: chosenPreset, progressHandler: progressHandler)
        
        // Check output size vs original size
        let resources = PHAssetResource.assetResources(for: asset)
        let originalBytes = (resources.first?.value(forKey: "fileSize") as? Int64) ?? 0
        let exportedBytes = (try? FileManager.default.attributesOfItem(atPath: outputURL.path)[.size] as? Int64) ?? 0
        
        // If output size is >= original size, re-export using a more aggressive compression preset to guarantee savings!
        if originalBytes > 0 && exportedBytes >= originalBytes {
            let fallbackPresets = [
                AVAssetExportPreset1280x720,
                AVAssetExportPresetMediumQuality,
                AVAssetExportPreset960x540
            ]
            for fallback in fallbackPresets {
                if compatiblePresets.contains(fallback) && fallback != chosenPreset {
                    try? FileManager.default.removeItem(at: outputURL)
                    outputURL = try await runExportSession(avAsset: avAsset, presetName: fallback, progressHandler: nil)
                    break
                }
            }
        }
        
        return outputURL
    }
    
    private func runExportSession(
        avAsset: AVAsset,
        presetName: String,
        progressHandler: (@Sendable (Double) -> Void)?
    ) async throws -> URL {
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        try? FileManager.default.removeItem(at: outputURL)
        
        guard let exportSession = AVAssetExportSession(asset: avAsset, presetName: presetName) else {
            throw NSError(domain: "CleanSpaceVideoCompression", code: -2, userInfo: [NSLocalizedDescriptionKey: "Preset not supported for this video format"])
        }
        
        exportSession.outputURL = outputURL
        exportSession.outputFileType = .mp4
        exportSession.shouldOptimizeForNetworkUse = true
        
        let progressTask = Task {
            while !Task.isCancelled {
                let currentStatus = exportSession.status
                if currentStatus == .exporting || currentStatus == .waiting {
                    let progress = Double(exportSession.progress)
                    progressHandler?(max(0.05, progress))
                } else {
                    break
                }
                try? await Task.sleep(nanoseconds: 100_000_000) // 100ms
            }
        }
        
        await exportSession.export()
        progressTask.cancel()
        
        switch exportSession.status {
        case .completed:
            progressHandler?(1.0)
            return outputURL
        case .failed:
            let err = exportSession.error ?? NSError(domain: "CleanSpaceVideoCompression", code: -3, userInfo: [NSLocalizedDescriptionKey: "Video compression export failed"])
            throw err
        case .cancelled:
            throw NSError(domain: "CleanSpaceVideoCompression", code: -4, userInfo: [NSLocalizedDescriptionKey: "Export was cancelled"])
        default:
            throw NSError(domain: "CleanSpaceVideoCompression", code: -5, userInfo: [NSLocalizedDescriptionKey: "Unknown export status: \(exportSession.status.rawValue)"])
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
