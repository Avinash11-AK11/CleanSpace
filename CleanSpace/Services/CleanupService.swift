//
//  CleanupService.swift
//  CleanSpace
//
//  Created by Avinash Chavda on 22/09/2026, 06:03 PM.
//  Copyright © 2026 Avinash Chavda. All rights reserved.
//

import Foundation
import Photos
import Contacts

final class CleanupService: Sendable {
    static let shared = CleanupService()
    
    private init() {}
    
    /// Safely deletes photos and videos via standard Photos framework change request
    func deleteAssets(assets: [PHAsset]) async throws {
        guard !assets.isEmpty else { return }
        try await PHPhotoLibrary.shared().performChanges {
            PHAssetChangeRequest.deleteAssets(assets as NSArray)
        }
    }
    
    /// Safely deletes contacts using CNSaveRequest
    func deleteContacts(contacts: [CNContact]) async throws {
        guard !contacts.isEmpty else { return }
        let store = CNContactStore()
        let saveRequest = CNSaveRequest()
        for contact in contacts {
            if let mutable = contact.mutableCopy() as? CNMutableContact {
                saveRequest.delete(mutable)
            }
        }
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try store.execute(saveRequest)
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Merges secondary duplicate contacts into primary contact and removes duplicates
    func mergeContacts(primary: CNContact, duplicates: [CNContact]) async throws {
        let store = CNContactStore()
        let saveRequest = CNSaveRequest()
        
        guard let mutablePrimary = primary.mutableCopy() as? CNMutableContact else { return }
        
        var existingPhones = Set(mutablePrimary.phoneNumbers.map { $0.value.stringValue })
        var existingEmails = Set(mutablePrimary.emailAddresses.map { $0.value as String })
        
        for dup in duplicates {
            for phone in dup.phoneNumbers {
                if !existingPhones.contains(phone.value.stringValue) {
                    existingPhones.insert(phone.value.stringValue)
                    mutablePrimary.phoneNumbers.append(phone)
                }
            }
            for email in dup.emailAddresses {
                if !existingEmails.contains(email.value as String) {
                    existingEmails.insert(email.value as String)
                    mutablePrimary.emailAddresses.append(email)
                }
            }
            if let mutableDup = dup.mutableCopy() as? CNMutableContact {
                saveRequest.delete(mutableDup)
            }
        }
        saveRequest.update(mutablePrimary)
        
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            DispatchQueue.global(qos: .userInitiated).async {
                do {
                    try store.execute(saveRequest)
                    continuation.resume(returning: ())
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
}
