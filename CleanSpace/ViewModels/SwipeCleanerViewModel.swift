//
//  SwipeCleanerViewModel.swift
//  CleanSpace
//
//  Created by Avinash Chavda on 23/09/2026, 10:55 AM.
//  Copyright © 2026 Avinash Chavda. All rights reserved.
//

import Foundation
import Photos
import SwiftUI

enum SwipeDecision {
    case keep
    case delete
}

struct SwipedAction {
    let item: PhotoItem
    let decision: SwipeDecision
}

@MainActor
final class SwipeCleanerViewModel: ObservableObject {
    @Published var photos: [PhotoItem] = []
    @Published var currentIndex: Int = 0
    @Published var history: [SwipedAction] = []
    
    @Published var queuedForDeletion: [PhotoItem] = []
    @Published var isFinished: Bool = false
    
    var currentPhoto: PhotoItem? {
        guard currentIndex < photos.count else { return nil }
        return photos[currentIndex]
    }
    
    var nextPhoto: PhotoItem? {
        let next = currentIndex + 1
        guard next < photos.count else { return nil }
        return photos[next]
    }
    
    var totalCleanableBytes: Int64 {
        queuedForDeletion.reduce(0) { $0 + $1.fileSize }
    }
    
    var formattedCleanableBytes: String {
        ByteCountFormatter.string(fromByteCount: totalCleanableBytes, countStyle: .file)
    }
    
    init(photos: [PhotoItem] = []) {
        self.photos = photos
    }
    
    func setPhotos(_ items: [PhotoItem]) {
        self.photos = items
        self.currentIndex = 0
        self.history = []
        self.queuedForDeletion = []
        self.isFinished = items.isEmpty
    }
    
    func swipe(decision: SwipeDecision) {
        guard let current = currentPhoto else { return }
        
        history.append(SwipedAction(item: current, decision: decision))
        if decision == .delete {
            queuedForDeletion.append(current)
        }
        
        currentIndex += 1
        if currentIndex >= photos.count {
            isFinished = true
        }
    }
    
    func undo() {
        guard let last = history.popLast() else { return }
        if last.decision == .delete {
            queuedForDeletion.removeAll { $0.id == last.item.id }
        }
        currentIndex = max(0, currentIndex - 1)
        isFinished = false
    }
}
