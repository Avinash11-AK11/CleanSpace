import Foundation

enum CleanupCategory: String, CaseIterable, Identifiable {
    case similarPhotos = "Similar Photos"
    case screenshots = "Screenshots"
    case largeVideos = "Large Videos"
    case contacts = "Duplicate Contacts"
    
    var id: String { rawValue }
    
    var iconName: String {
        switch self {
        case .similarPhotos: return "photo.on.rectangle.angled"
        case .screenshots: return "camera.viewfinder"
        case .largeVideos: return "film.stack"
        case .contacts: return "person.crop.circle.badge.exclamationmark"
        }
    }
}

struct CleanupSummary {
    var photoCount: Int = 0
    var photoBytes: Int64 = 0
    
    var screenshotCount: Int = 0
    var screenshotBytes: Int64 = 0
    
    var videoCount: Int = 0
    var videoBytes: Int64 = 0
    
    var contactCount: Int = 0
    
    var totalItemCount: Int {
        photoCount + screenshotCount + videoCount + contactCount
    }
    
    var totalBytes: Int64 {
        photoBytes + screenshotBytes + videoBytes
    }
    
    var formattedTotalBytes: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
}
