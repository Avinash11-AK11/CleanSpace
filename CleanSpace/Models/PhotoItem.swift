//
//  PhotoItem.swift
//  CleanSpace
//
//  Created by Avinash Chavda on 22/09/2026, 06:03 PM.
//  Copyright © 2026 Avinash Chavda. All rights reserved.
//

import Foundation
import Photos

struct PhotoItem: Identifiable, Hashable, @unchecked Sendable {
    let id: String
    let asset: PHAsset
    let creationDate: Date?
    let pixelWidth: Int
    let pixelHeight: Int
    let isFavorite: Bool
    let isScreenshot: Bool
    var fileSize: Int64
    
    init(asset: PHAsset, fileSize: Int64 = 0) {
        self.id = asset.localIdentifier
        self.asset = asset
        self.creationDate = asset.creationDate
        self.pixelWidth = asset.pixelWidth
        self.pixelHeight = asset.pixelHeight
        self.isFavorite = asset.isFavorite
        self.isScreenshot = asset.mediaSubtypes.contains(.photoScreenshot)
        self.fileSize = fileSize
    }
    
    var formattedSize: String {
        ByteCountFormatter.string(fromByteCount: fileSize, countStyle: .file)
    }
    
    var resolutionString: String {
        "\(pixelWidth) × \(pixelHeight)"
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: PhotoItem, rhs: PhotoItem) -> Bool {
        lhs.id == rhs.id
    }
}
