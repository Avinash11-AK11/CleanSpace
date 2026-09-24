//
//  VideoGroup.swift
//  CleanSpace
//
//  Created by Avinash Chavda on 23/09/2026, 01:20 AM.
//  Copyright © 2026 Avinash Chavda. All rights reserved.
//

import Foundation
import Photos

struct VideoGroup: Identifiable, Hashable, @unchecked Sendable {
    let id: String
    var recommendedBestId: String?
    var videos: [VideoItem]
    
    var cleanableSize: Int64 {
        guard let bestId = recommendedBestId else {
            return videos.dropFirst().reduce(0) { $0 + $1.fileSize }
        }
        return videos.filter { $0.id != bestId }.reduce(0) { $0 + $1.fileSize }
    }
    
    var formattedCleanableSize: String {
        ByteCountFormatter.string(fromByteCount: cleanableSize, countStyle: .file)
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: VideoGroup, rhs: VideoGroup) -> Bool {
        lhs.id == rhs.id
    }
}
