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
    @Published var similarPhotoGroups: [PhotoGroup] = []
    @Published var screenshots: [PhotoItem] = []
    @Published var largeVideos: [VideoItem] = []
    @Published var duplicateContactGroups: [ContactGroup] = []
    
    // Computed cleanable estimates
    @Published var cleanablePhotoBytes: Int64 = 0
    @Published var cleanableScreenshotBytes: Int64 = 0
    @Published var cleanableVideoBytes: Int64 = 0
    
    var totalCleanableBytes: Int64 {
        cleanablePhotoBytes + cleanableScreenshotBytes + cleanableVideoBytes
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
        
        // Scan Photos if permission granted
        if permissions.hasPhotoAccess {
            currentTask = "Fetching photos and screenshots..."
            scanProgress = 0.1
            
            // 1. Screenshots
            let shots = ScreenshotScanner.shared.fetchScreenshots()
            self.screenshots = shots
            self.cleanableScreenshotBytes = shots.reduce(0) { $0 + $1.fileSize }
            for shot in shots {
                CleanupManager.shared.allScreenshotsMap[shot.id] = shot
            }
            
            // 2. Similar photos
            currentTask = "Analyzing photos for similarities..."
            let allPhotos = PhotoScanner.shared.fetchAllPhotos()
            let groups = await PhotoSimilarityService.shared.findSimilarGroups(photos: allPhotos) { [weak self] progress, task in
                Task { @MainActor in
                    self?.scanProgress = 0.2 + progress * 0.45
                    self?.currentTask = task
                }
            }
            self.similarPhotoGroups = groups
            self.cleanablePhotoBytes = groups.reduce(0) { $0 + $1.cleanableSize }
            for group in groups {
                for photo in group.photos {
                    CleanupManager.shared.allPhotosMap[photo.id] = photo
                }
            }
            
            // 3. Large Videos
            currentTask = "Scanning for large videos..."
            scanProgress = 0.7
            let videos = VideoScanner.shared.fetchLargeVideos()
            self.largeVideos = videos
            self.cleanableVideoBytes = videos.reduce(0) { $0 + $1.fileSize }
            for video in videos {
                CleanupManager.shared.allVideosMap[video.id] = video
            }
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
            } catch {
                print("Failed to scan contacts: \(error)")
            }
        }
        
        scanProgress = 1.0
        currentTask = "Scan complete"
        try? await Task.sleep(nanoseconds: 300_000_000)
        isScanning = false
    }
}
