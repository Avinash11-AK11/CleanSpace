import Foundation
import Photos
import Contacts
import SwiftUI

@MainActor
final class DashboardViewModel: ObservableObject {
    @Published var storageInfo: StorageInfo = .zero
    @Published var isScanning: Bool = false
    @Published var scanProgress: Double = 0.0
    @Published var currentTask: String = ""
    
    // Found cleanup items
    @Published var allPhotos: [PhotoItem] = []
    @Published var similarPhotoGroups: [PhotoGroup] = []
    @Published var screenshots: [PhotoItem] = []
    @Published var largeVideos: [VideoItem] = []
    @Published var duplicateVideoGroups: [VideoGroup] = []
    @Published var duplicateContactGroups: [ContactGroup] = []
    
    // Computed cleanable estimates
    @Published var cleanablePhotoBytes: Int64 = 0
    @Published var cleanableScreenshotBytes: Int64 = 0
    @Published var cleanableVideoBytes: Int64 = 0
    @Published var cleanableDuplicateVideoBytes: Int64 = 0
    @Published var blurryPhotos: [BlurryPhotoItem] = []
    @Published var cleanableBlurryBytes: Int64 = 0
    
    var totalCleanableBytes: Int64 {
        cleanablePhotoBytes + cleanableScreenshotBytes + cleanableVideoBytes + cleanableBlurryBytes
    }
    
    var formattedTotalCleanable: String {
        ByteCountFormatter.string(fromByteCount: totalCleanableBytes, countStyle: .file)
    }
    
    init() {
        refreshStorage()
    }
    
    func refreshStorage() {
        self.storageInfo = StorageService.shared.getStorageInfo()
    }
    
    func startFullScan() async {
        guard !isScanning else { return }
        isScanning = true
        scanProgress = 0.0
        currentTask = "Initializing scan..."
        
        refreshStorage()
        
        let permissions = PermissionManager.shared
        permissions.refreshStatuses()
        print("CleanSpace: Scanning with photoStatus = \(permissions.photoStatus.rawValue), contactStatus = \(permissions.contactStatus.rawValue)")
        
        // Scan Photos if permission granted
        if permissions.hasPhotoAccess {
            currentTask = "Fetching photos and screenshots..."
            scanProgress = 0.1
            
            // 1. Screenshots
            let shots = await Task.detached(priority: .userInitiated) {
                ScreenshotScanner.shared.fetchScreenshots()
            }.value
            self.screenshots = shots
            self.cleanableScreenshotBytes = shots.reduce(0) { $0 + $1.fileSize }
            for shot in shots {
                CleanupManager.shared.allScreenshotsMap[shot.id] = shot
            }
            print("CleanSpace: Fetched \(shots.count) screenshots")
            
            // 2. Photos & Similar photos
            currentTask = "Analyzing photos for similarities..."
            let (allPhotoAssets, photoItems) = await Task.detached(priority: .userInitiated) {
                let assets = PhotoScanner.shared.fetchAllPhotos()
                let items = assets.map { PhotoItem(asset: $0, fileSize: PhotoScanner.shared.estimateAssetSize(asset: $0)) }
                return (assets, items)
            }.value
            print("CleanSpace: Fetched \(allPhotoAssets.count) total photo assets")
            self.allPhotos = photoItems
            for p in photoItems {
                CleanupManager.shared.allPhotosMap[p.id] = p
            }
            
            let groups = await PhotoSimilarityService.shared.findSimilarGroups(photos: allPhotoAssets) { [weak self] progress, task in
                Task { @MainActor in
                    self?.scanProgress = 0.2 + progress * 0.45
                    self?.currentTask = task
                }
            }
            self.similarPhotoGroups = groups
            self.cleanablePhotoBytes = groups.reduce(0) { $0 + $1.cleanableSize }
            print("CleanSpace: Found \(groups.count) similar photo groups")
            
            // 3. Blurry Photos
            currentTask = "Detecting blurry and out-of-focus photos..."
            let blurry = await BlurDetectionService.shared.detectBlurryPhotos(photos: allPhotoAssets)
            self.blurryPhotos = blurry
            self.cleanableBlurryBytes = blurry.reduce(0) { $0 + $1.photo.fileSize }
            for b in blurry {
                CleanupManager.shared.allPhotosMap[b.id] = b.photo
            }
            print("CleanSpace: Found \(blurry.count) blurry photos")
            
            // 4. Large & Duplicate Videos
            currentTask = "Scanning for large and duplicate videos..."
            scanProgress = 0.7
            let (videos, dupVideos) = await Task.detached(priority: .userInitiated) {
                let vids = VideoScanner.shared.fetchLargeVideos()
                let dups = VideoScanner.shared.findDuplicateVideoGroups(videos: vids)
                return (vids, dups)
            }.value
            self.largeVideos = videos
            self.cleanableVideoBytes = videos.reduce(0) { $0 + $1.fileSize }
            
            self.duplicateVideoGroups = dupVideos
            self.cleanableDuplicateVideoBytes = dupVideos.reduce(0) { $0 + $1.cleanableSize }
            
            for video in videos {
                CleanupManager.shared.allVideosMap[video.id] = video
            }
            print("CleanSpace: Fetched \(videos.count) videos and \(dupVideos.count) duplicate video groups")
        } else {
            print("CleanSpace: Photo access not granted (status = \(permissions.photoStatus.rawValue))")
        }
        
        // 4. Contacts
        if permissions.hasContactAccess {
            currentTask = "Scanning duplicate contacts..."
            scanProgress = 0.85
            do {
                let contacts = try await ContactScanner.shared.fetchContacts()
                let dupGroups = ContactScanner.shared.findDuplicateGroups(contacts: contacts)
                self.duplicateContactGroups = dupGroups
                for group in dupGroups {
                    for contact in group.contacts {
                        CleanupManager.shared.allContactsMap[contact.id] = contact
                    }
                }
                print("CleanSpace: Found \(dupGroups.count) duplicate contact groups")
            } catch {
                print("CleanSpace: Failed to scan contacts: \(error)")
            }
        }
        
        scanProgress = 1.0
        currentTask = "Scan complete"
        try? await Task.sleep(nanoseconds: 300_000_000)
        isScanning = false
    }
}
