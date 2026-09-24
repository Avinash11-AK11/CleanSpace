//
//  VaultManager.swift
//  CleanSpace
//
//  Created by Avinash Chavda on 23/09/2026, 10:55 AM.
//  Copyright © 2026 Avinash Chavda. All rights reserved.
//

import Foundation
import Photos
import UIKit
import LocalAuthentication
import CryptoKit

struct VaultMediaItem: Identifiable, Codable, Hashable, Sendable {
    let id: UUID
    let filename: String
    let mediaType: String // "image" or "video"
    let fileSize: Int64
    let dateAdded: Date
    let originalCreationDate: Date?
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    var isVideo: Bool {
        mediaType == "video"
    }
}

@MainActor
final class VaultManager: ObservableObject {
    static let shared = VaultManager()
    
    @Published var isUnlocked: Bool = false
    @Published var items: [VaultMediaItem] = []
    
    private let vaultDirectory: URL
    private let metadataURL: URL
    private let pinKey = "CleanSpaceVaultPINHash"
    
    private init() {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        self.vaultDirectory = appSupport.appendingPathComponent("CleanSpaceVault", isDirectory: true)
        self.metadataURL = vaultDirectory.appendingPathComponent("vault_metadata.json")
        
        try? FileManager.default.createDirectory(at: vaultDirectory, withIntermediateDirectories: true, attributes: [
            FileAttributeKey.protectionKey: FileProtectionType.completeUnlessOpen
        ])
        
        loadMetadata()
    }
    
    var hasPINConfigured: Bool {
        UserDefaults.standard.string(forKey: pinKey) != nil
    }
    
    var totalVaultBytes: Int64 {
        items.reduce(0) { $0 + $1.fileSize }
    }
    
    var formattedVaultSize: String {
        ByteCountFormatter.string(fromByteCount: totalVaultBytes, countStyle: .file)
    }
    
    // MARK: - Authentication
    
    func setPIN(_ pin: String) {
        let hash = hashString(pin)
        UserDefaults.standard.set(hash, forKey: pinKey)
    }
    
    func verifyPIN(_ pin: String) -> Bool {
        guard let storedHash = UserDefaults.standard.string(forKey: pinKey) else { return false }
        let enteredHash = hashString(pin)
        let isValid = enteredHash == storedHash
        if isValid {
            isUnlocked = true
        }
        return isValid
    }
    
    func authenticateWithBiometrics() async -> Bool {
        let context = LAContext()
        var error: NSError?
        
        guard context.canEvaluatePolicy(.deviceOwnerAuthenticationWithBiometrics, error: &error) else {
            return false
        }
        
        return await withCheckedContinuation { continuation in
            context.evaluatePolicy(
                .deviceOwnerAuthenticationWithBiometrics,
                localizedReason: "Unlock your private CleanSpace Vault"
            ) { success, _ in
                DispatchQueue.main.async {
                    if success {
                        self.isUnlocked = true
                    }
                    continuation.resume(returning: success)
                }
            }
        }
    }
    
    func lock() {
        isUnlocked = false
    }
    
    private func hashString(_ text: String) -> String {
        let data = Data(text.utf8)
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02hhx", $0) }.joined()
    }
    
    // MARK: - File Management
    
    func fileURL(for item: VaultMediaItem) -> URL {
        vaultDirectory.appendingPathComponent(item.filename)
    }
    
    func importAsset(_ asset: PHAsset, deleteOriginal: Bool = false) async throws {
        let id = UUID()
        let isVideo = asset.mediaType == .video
        let ext = isVideo ? "mp4" : "jpg"
        let filename = "\(id.uuidString).\(ext)"
        let targetURL = vaultDirectory.appendingPathComponent(filename)
        
        var fileSize: Int64 = 0
        
        if isVideo {
            try await exportVideoData(from: asset, to: targetURL)
            let attrs = try? FileManager.default.attributesOfItem(atPath: targetURL.path)
            fileSize = (attrs?[.size] as? Int64) ?? 5_000_000
        } else {
            let data = try await exportImageData(from: asset)
            try data.write(to: targetURL, options: .atomic)
            fileSize = Int64(data.count)
        }
        
        let item = VaultMediaItem(
            id: id,
            filename: filename,
            mediaType: isVideo ? "video" : "image",
            fileSize: fileSize,
            dateAdded: Date(),
            originalCreationDate: asset.creationDate
        )
        
        items.insert(item, at: 0)
        saveMetadata()
        
        if deleteOriginal {
            try await CleanupService.shared.deleteAssets(assets: [asset])
            CleanupManager.shared.deletedAssetIds.insert(asset.localIdentifier)
        }
    }
    
    func exportItemToPhotos(_ item: VaultMediaItem) async throws {
        let url = fileURL(for: item)
        try await PHPhotoLibrary.shared().performChanges {
            if item.isVideo {
                PHAssetChangeRequest.creationRequestForAssetFromVideo(atFileURL: url)
            } else {
                PHAssetChangeRequest.creationRequestForAssetFromImage(atFileURL: url)
            }
        }
    }
    
    func deleteItem(_ item: VaultMediaItem) {
        let url = fileURL(for: item)
        try? FileManager.default.removeItem(at: url)
        items.removeAll { $0.id == item.id }
        saveMetadata()
    }
    
    private func exportImageData(from asset: PHAsset) async throws -> Data {
        try await withCheckedThrowingContinuation { continuation in
            let options = PHImageRequestOptions()
            options.isNetworkAccessAllowed = true
            options.isSynchronous = false
            
            PHImageManager.default().requestImageDataAndOrientation(for: asset, options: options) { data, _, _, info in
                if let error = info?[PHImageErrorKey] as? Error {
                    continuation.resume(throwing: error)
                } else if let data = data {
                    continuation.resume(returning: data)
                } else {
                    continuation.resume(throwing: NSError(domain: "CleanSpaceVault", code: -1, userInfo: [NSLocalizedDescriptionKey: "Failed to read image data"]))
                }
            }
        }
    }
    
    private func exportVideoData(from asset: PHAsset, to destinationURL: URL) async throws {
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
                    continuation.resume(throwing: NSError(domain: "CleanSpaceVault", code: -2, userInfo: [NSLocalizedDescriptionKey: "Failed to read video asset"]))
                }
            }
        }
        
        guard let session = AVAssetExportSession(asset: avAsset, presetName: AVAssetExportPresetHighestQuality) else {
            throw NSError(domain: "CleanSpaceVault", code: -3, userInfo: [NSLocalizedDescriptionKey: "Could not create export session"])
        }
        
        session.outputURL = destinationURL
        session.outputFileType = .mp4
        await session.export()
        
        if session.status != .completed {
            throw session.error ?? NSError(domain: "CleanSpaceVault", code: -4, userInfo: [NSLocalizedDescriptionKey: "Video export failed"])
        }
    }
    
    private func loadMetadata() {
        guard let data = try? Data(contentsOf: metadataURL),
              let loaded = try? JSONDecoder().decode([VaultMediaItem].self, from: data) else {
            self.items = []
            return
        }
        self.items = loaded
    }
    
    private func saveMetadata() {
        guard let data = try? JSONEncoder().encode(items) else { return }
        try? data.write(to: metadataURL, options: .atomic)
    }
}
