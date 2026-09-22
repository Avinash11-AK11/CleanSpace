import Foundation
import Photos
import Contacts
import SwiftUI

@MainActor
final class CleanupManager: ObservableObject {
    static let shared = CleanupManager()
    
    // Selected IDs
    @Published var selectedPhotoIds: Set<String> = []
    @Published var selectedScreenshotIds: Set<String> = []
    @Published var selectedVideoIds: Set<String> = []
    @Published var selectedContactIds: Set<String> = []
    
    // Live tracking of deleted items to sync across all open views
    @Published var deletedAssetIds: Set<String> = []
    @Published var deletedContactIds: Set<String> = []
    
    // Cached item maps for fast lookup and summary computation
    var allPhotosMap: [String: PhotoItem] = [:]
    var allScreenshotsMap: [String: PhotoItem] = [:]
    var allVideosMap: [String: VideoItem] = [:]
    var allContactsMap: [String: ContactItem] = [:]
    
    // Track space freed in the current session
    @Published var lastFreedBytes: Int64 = 0
    @Published var lastFreedItemCount: Int = 0
    
    init() {}
    
    func togglePhoto(_ item: PhotoItem) {
        if selectedPhotoIds.contains(item.id) {
            selectedPhotoIds.remove(item.id)
        } else {
            selectedPhotoIds.insert(item.id)
        }
        allPhotosMap[item.id] = item
    }
    
    func toggleScreenshot(_ item: PhotoItem) {
        if selectedScreenshotIds.contains(item.id) {
            selectedScreenshotIds.remove(item.id)
        } else {
            selectedScreenshotIds.insert(item.id)
        }
        allScreenshotsMap[item.id] = item
    }
    
    func toggleVideo(_ item: VideoItem) {
        if selectedVideoIds.contains(item.id) {
            selectedVideoIds.remove(item.id)
        } else {
            selectedVideoIds.insert(item.id)
        }
        allVideosMap[item.id] = item
    }
    
    func toggleContact(_ item: ContactItem) {
        if selectedContactIds.contains(item.id) {
            selectedContactIds.remove(item.id)
        } else {
            selectedContactIds.insert(item.id)
        }
        allContactsMap[item.id] = item
    }
    
    func selectAllScreenshots(_ items: [PhotoItem]) {
        for item in items {
            selectedScreenshotIds.insert(item.id)
            allScreenshotsMap[item.id] = item
        }
    }
    
    func deselectAllScreenshots() {
        selectedScreenshotIds.removeAll()
    }
    
    func selectAllDuplicatesExcludingBest(groups: [PhotoGroup]) {
        for group in groups {
            guard let bestId = group.recommendedBestId else { continue }
            for photo in group.photos where photo.id != bestId {
                selectedPhotoIds.insert(photo.id)
                allPhotosMap[photo.id] = photo
            }
        }
    }
    
    func selectAllPhotos(_ items: [PhotoItem]) {
        for item in items {
            selectedPhotoIds.insert(item.id)
            allPhotosMap[item.id] = item
        }
    }
    
    func deselectAllPhotos() {
        selectedPhotoIds.removeAll()
    }
    
    func selectAllDuplicateVideosExcludingBest(groups: [VideoGroup]) {
        for group in groups {
            guard let bestId = group.recommendedBestId else { continue }
            for video in group.videos where video.id != bestId {
                selectedVideoIds.insert(video.id)
                allVideosMap[video.id] = video
            }
        }
    }
    
    func deselectAllVideos() {
        selectedVideoIds.removeAll()
    }
    
    var totalSelectedCount: Int {
        selectedPhotoIds.count + selectedScreenshotIds.count + selectedVideoIds.count + selectedContactIds.count
    }
    
    var formattedTotalSelectedCount: String {
        totalSelectedCount == 1 ? "1 item selected" : "\(totalSelectedCount) items selected"
    }
    
    var totalEstimatedBytes: Int64 {
        let photoBytes = selectedPhotoIds.compactMap { allPhotosMap[$0]?.fileSize }.reduce(0, +)
        let screenshotBytes = selectedScreenshotIds.compactMap { allScreenshotsMap[$0]?.fileSize }.reduce(0, +)
        let videoBytes = selectedVideoIds.compactMap { allVideosMap[$0]?.fileSize }.reduce(0, +)
        return photoBytes + screenshotBytes + videoBytes
    }
    
    var formattedEstimatedBytes: String {
        ByteCountFormatter.string(fromByteCount: totalEstimatedBytes, countStyle: .file)
    }
    
    func recordDeletedItems(assetIds: Set<String>, contactIds: Set<String>) {
        deletedAssetIds.formUnion(assetIds)
        deletedContactIds.formUnion(contactIds)
        
        // Remove from maps
        for id in assetIds {
            allPhotosMap.removeValue(forKey: id)
            allScreenshotsMap.removeValue(forKey: id)
            allVideosMap.removeValue(forKey: id)
        }
        for id in contactIds {
            allContactsMap.removeValue(forKey: id)
        }
    }
    
    func clearAllSelections() {
        selectedPhotoIds.removeAll()
        selectedScreenshotIds.removeAll()
        selectedVideoIds.removeAll()
        selectedContactIds.removeAll()
    }
}
