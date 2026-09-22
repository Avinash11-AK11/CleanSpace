import Foundation

struct StorageInfo: Sendable {
    let totalBytes: Int64
    let freeBytes: Int64
    
    var usedBytes: Int64 {
        max(0, totalBytes - freeBytes)
    }
    
    var usedPercentage: Double {
        guard totalBytes > 0 else { return 0.0 }
        return Double(usedBytes) / Double(totalBytes)
    }
    
    var formattedTotal: String {
        ByteCountFormatter.string(fromByteCount: totalBytes, countStyle: .file)
    }
    
    var formattedFree: String {
        ByteCountFormatter.string(fromByteCount: freeBytes, countStyle: .file)
    }
    
    var formattedUsed: String {
        ByteCountFormatter.string(fromByteCount: usedBytes, countStyle: .file)
    }
    
    static let zero = StorageInfo(totalBytes: 0, freeBytes: 0)
}
