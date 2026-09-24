//
//  ContactScanner.swift
//  CleanSpace
//
//  Created by Avinash Chavda on 22/09/2026, 06:03 PM.
//  Copyright © 2026 Avinash Chavda. All rights reserved.
//

import Foundation
import Contacts

final class ContactScanner: Sendable {
    static let shared = ContactScanner()
    
    private init() {}
    
    func fetchContacts() async throws -> [ContactItem] {
        let store = CNContactStore()
        let keys: [CNKeyDescriptor] = [
            CNContactIdentifierKey as CNKeyDescriptor,
            CNContactGivenNameKey as CNKeyDescriptor,
            CNContactFamilyNameKey as CNKeyDescriptor,
            CNContactPhoneNumbersKey as CNKeyDescriptor,
            CNContactEmailAddressesKey as CNKeyDescriptor
        ]
        
        let request = CNContactFetchRequest(keysToFetch: keys)
        return try await withCheckedThrowingContinuation { continuation in
            DispatchQueue.global(qos: .userInitiated).async {
                var contacts: [ContactItem] = []
                do {
                    try store.enumerateContacts(with: request) { contact, _ in
                        contacts.append(ContactItem(contact: contact))
                    }
                    continuation.resume(returning: contacts)
                } catch {
                    continuation.resume(throwing: error)
                }
            }
        }
    }
    
    /// Finds duplicate contacts grouped by identical normalized phone numbers, emails, or names
    func findDuplicateGroups(contacts: [ContactItem]) -> [ContactGroup] {
        var groups: [ContactGroup] = []
        var processedIds = Set<String>()
        
        // Group by normalized phone number (e.g. +1 (555) 123-4567 -> 5551234567)
        var phoneMap: [String: [ContactItem]] = [:]
        for c in contacts {
            for rawPhone in c.phoneNumbers {
                let normalized = normalizePhone(rawPhone)
                if normalized.count >= 7 {
                    phoneMap[normalized, default: []].append(c)
                }
            }
        }
        
        for (phone, matchingContacts) in phoneMap {
            let uniqueMatches = Array(Dictionary(grouping: matchingContacts, by: { $0.id }).compactMap { $0.value.first })
            if uniqueMatches.count > 1 {
                let unvisited = uniqueMatches.filter { !processedIds.contains($0.id) }
                if unvisited.count > 1 {
                    for u in unvisited { processedIds.insert(u.id) }
                    groups.append(ContactGroup(
                        contacts: unvisited,
                        reason: "Matching phone number (\(phone))",
                        recommendedKeepId: unvisited.first?.id
                    ))
                }
            }
        }
        
        // Group by normalized email
        var emailMap: [String: [ContactItem]] = [:]
        for c in contacts {
            for email in c.emailAddresses {
                let normalized = email.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
                if !normalized.isEmpty {
                    emailMap[normalized, default: []].append(c)
                }
            }
        }
        
        for (email, matchingContacts) in emailMap {
            let uniqueMatches = Array(Dictionary(grouping: matchingContacts, by: { $0.id }).compactMap { $0.value.first })
            if uniqueMatches.count > 1 {
                let unvisited = uniqueMatches.filter { !processedIds.contains($0.id) }
                if unvisited.count > 1 {
                    for u in unvisited { processedIds.insert(u.id) }
                    groups.append(ContactGroup(
                        contacts: unvisited,
                        reason: "Matching email (\(email))",
                        recommendedKeepId: unvisited.first?.id
                    ))
                }
            }
        }
        
        // Group by exact full name
        var nameMap: [String: [ContactItem]] = [:]
        for c in contacts {
            let name = c.fullName.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
            if name.count > 2 && name != "unnamed contact" {
                nameMap[name, default: []].append(c)
            }
        }
        
        for (name, matchingContacts) in nameMap {
            let uniqueMatches = Array(Dictionary(grouping: matchingContacts, by: { $0.id }).compactMap { $0.value.first })
            if uniqueMatches.count > 1 {
                let unvisited = uniqueMatches.filter { !processedIds.contains($0.id) }
                if unvisited.count > 1 {
                    for u in unvisited { processedIds.insert(u.id) }
                    groups.append(ContactGroup(
                        contacts: unvisited,
                        reason: "Identical full name (\(name.capitalized))",
                        recommendedKeepId: unvisited.first?.id
                    ))
                }
            }
        }
        
        return groups
    }
    
    private func normalizePhone(_ phone: String) -> String {
        let digits = phone.filter { $0.isNumber }
        if digits.count > 10 {
            return String(digits.suffix(10))
        }
        return digits
    }
}
