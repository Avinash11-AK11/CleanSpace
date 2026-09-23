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
            #if targetEnvironment(simulator)
            return [
                AVAssetExportPreset1920x1080,
                AVAssetExportPreset1280x720,
                AVAssetExportPresetMediumQuality
            ]
            #else
            return [
                AVAssetExportPresetHEVC1920x1080,
                AVAssetExportPreset1920x1080,
                AVAssetExportPreset1280x720,
                AVAssetExportPresetMediumQuality
            ]
            #endif
        case .medium:
            #if targetEnvironment(simulator)
            return [
                AVAssetExportPreset1280x720,
                AVAssetExportPresetMediumQuality,
                AVAssetExportPreset960x540
            ]
            #else
            return [
                AVAssetExportPresetHEVC1280x720,
                AVAssetExportPreset1280x720,
                AVAssetExportPresetMediumQuality,
                AVAssetExportPreset960x540
            ]
            #endif
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
            return 0.65 // ~65% savings with 1080p
        case .medium:
            return 0.80 // ~80% savings with 720p
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
        let ratePerSecond: Double
        switch preset {
        case .high: ratePerSecond = 560_000
        case .medium: ratePerSecond = 275_000
        case .low: ratePerSecond = 125_000
        }
        
        let durationBased = duration > 0 ? Int64(duration * ratePerSecond) : originalBytes / 2
        let factorBased = Int64(Double(originalBytes) * (1.0 - preset.reductionFactor))
        let target = min(durationBased, factorBased)
        
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
        
        for candidate in preset.preferredPresetNames {
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
