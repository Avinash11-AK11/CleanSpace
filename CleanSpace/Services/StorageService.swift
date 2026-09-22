import Foundation

final class StorageService: Sendable {
    static let shared = StorageService()
    
    private init() {}
    
    func getStorageInfo() -> StorageInfo {
        let homeUrl = URL(fileURLWithPath: NSHomeDirectory())
        do {
            let values = try homeUrl.resourceValues(forKeys: [.volumeTotalCapacityKey, .volumeAvailableCapacityKey])
            let total = Int64(values.volumeTotalCapacity ?? 0)
            let free = Int64(values.volumeAvailableCapacity ?? 0)
            return StorageInfo(totalBytes: total, freeBytes: free)
        } catch {
            return StorageInfo.zero
        }
    }
}
