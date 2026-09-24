//
//  VideoItem.swift
//  CleanSpace
//
//  Created by Avinash Chavda on 22/09/2026, 06:03 PM.
//  Copyright © 2026 Avinash Chavda. All rights reserved.
//

import Foundation
import Photos

struct VideoItem: Identifiable, Hashable, @unchecked Sendable {
    let id: String
    let asset: PHAsset
    let duration: TimeInterval
    let creationDate: Date?
    let pixelWidth: Int
    let pixelHeight: Int
    var fileSize: Int64
    
    init(asset: PHAsset, fileSize: Int64 = 0) {
        self.id = asset.localIdentifier
        self.asset = asset
        self.duration = asset.duration
        self.creationDate = asset.creationDate
        self.pixelWidth = asset.pixelWidth
        self.pixelHeight = asset.pixelHeight
        self.fileSize = fileSize
    }
    
    var formattedDuration: String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
    }
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    var qualityLabel: String {
        if pixelHeight >= 2160 || pixelWidth >= 2160 {
            return "4K"
        } else if pixelHeight >= 1080 || pixelWidth >= 1080 {
            return "1080p HD"
        } else if pixelHeight >= 720 || pixelWidth >= 720 {
            return "720p HD"
        } else {
            return "SD"
        }
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: VideoItem, rhs: VideoItem) -> Bool {
        lhs.id == rhs.id
    }
}
