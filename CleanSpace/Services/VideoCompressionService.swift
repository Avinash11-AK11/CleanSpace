import Foundation
import Photos
import AVFoundation

enum CompressionPreset: String, CaseIterable, Identifiable, Sendable {
    case high = "1080p High Quality"
    case medium = "720p Balanced (Recommended)"
    case low = "540p Maximum Savings"
    
    var id: String { rawValue }
    
    var avPresetName: String {
        switch self {
        case .high:
            return AVAssetExportPreset1920x1080
        case .medium:
            return AVAssetExportPreset1280x720
        case .low:
            return AVAssetExportPreset960x540
        }
    }
    
    var reductionFactor: Double {
        switch self {
        case .high:
            return 0.50 // ~50% savings
        case .medium:
            return 0.72 // ~72% savings
        case .low:
            return 0.85 // ~85% savings
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
    
    /// Estimates compressed file size for a given preset
    func estimateCompressedSize(originalBytes: Int64, preset: CompressionPreset) -> Int64 {
        let estimated = Int64(Double(originalBytes) * (1.0 - preset.reductionFactor))
        return max(500_000, estimated)
    }
    
    /// Compresses a video asset with real-time progress callbacks
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
        
        // Find compatible export preset or fallback
        let compatiblePresets = AVAssetExportSession.exportPresets(compatibleWith: avAsset)
        var targetPreset = preset.avPresetName
        if !compatiblePresets.contains(targetPreset) {
            if compatiblePresets.contains(AVAssetExportPreset1280x720) {
                targetPreset = AVAssetExportPreset1280x720
            } else if compatiblePresets.contains(AVAssetExportPresetMediumQuality) {
                targetPreset = AVAssetExportPresetMediumQuality
            } else if let first = compatiblePresets.first {
                targetPreset = first
            }
        }
        
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent(UUID().uuidString)
            .appendingPathExtension("mp4")
        
        try? FileManager.default.removeItem(at: outputURL)
        
        guard let exportSession = AVAssetExportSession(asset: avAsset, presetName: targetPreset) else {
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
