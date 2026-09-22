import Foundation

struct PhotoGroup: Identifiable, Hashable {
    let id: UUID
    var photos: [PhotoItem]
    var recommendedBestId: String?
    let similarityScore: Double
    
    init(id: UUID = UUID(), photos: [PhotoItem], recommendedBestId: String? = nil, similarityScore: Double = 0.95) {
        self.id = id
        self.photos = photos
        self.recommendedBestId = recommendedBestId
        self.similarityScore = similarityScore
    }
    
    var totalSize: Int64 {
        photos.reduce(0) { $0 + $1.fileSize }
    }
    
    /// Estimated recoverable size if best photo is kept and others are removed
    var cleanableSize: Int64 {
        guard let bestId = recommendedBestId else {
            return photos.dropFirst().reduce(0) { $0 + $1.fileSize }
        }
        return photos.filter { $0.id != bestId }.reduce(0) { $0 + $1.fileSize }
    }
    
    var formattedCleanableSize: String {
        ByteCountFormatter.string(fromByteCount: cleanableSize, countStyle: .file)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: PhotoGroup, rhs: PhotoGroup) -> Bool {
        lhs.id == rhs.id
    }
}
