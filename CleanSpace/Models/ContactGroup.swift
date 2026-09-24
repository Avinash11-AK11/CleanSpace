//
//  ContactGroup.swift
//  CleanSpace
//
//  Created by Avinash Chavda on 22/09/2026, 06:03 PM.
//  Copyright © 2026 Avinash Chavda. All rights reserved.
//

import Foundation

struct ContactGroup: Identifiable, Hashable {
    let id: UUID
    var contacts: [ContactItem]
    let reason: String
    var recommendedKeepId: String?
    
    init(id: UUID = UUID(), contacts: [ContactItem], reason: String, recommendedKeepId: String? = nil) {
        self.id = id
        self.contacts = contacts
        self.reason = reason
        self.recommendedKeepId = recommendedKeepId ?? contacts.first?.id
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ContactGroup, rhs: ContactGroup) -> Bool {
        lhs.id == rhs.id
    }
}
