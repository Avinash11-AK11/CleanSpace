//
//  ScreenshotScanner.swift
//  CleanSpace
//
//  Created by Avinash Chavda on 22/09/2026, 06:03 PM.
//  Copyright © 2026 Avinash Chavda. All rights reserved.
//

import Foundation
import Photos

final class ScreenshotScanner: Sendable {
    static let shared = ScreenshotScanner()
    
    private init() {}
    
    func fetchScreenshots() -> [PhotoItem] {
        let options = PHFetchOptions()
        options.sortDescriptors = [NSSortDescriptor(key: "creationDate", ascending: false)]
        options.predicate = NSPredicate(
            format: "mediaType == %d AND (mediaSubtype & %d) != 0",
            PHAssetMediaType.image.rawValue,
            PHAssetMediaSubtype.photoScreenshot.rawValue
        )
        
        let result = PHAsset.fetchAssets(with: .image, options: options)
        var items: [PhotoItem] = []
        items.reserveCapacity(result.count)
        
        result.enumerateObjects { asset, _, _ in
            let size = PhotoScanner.shared.estimateAssetSize(asset: asset)
            items.append(PhotoItem(asset: asset, fileSize: size))
        }
        return items
    }
}
