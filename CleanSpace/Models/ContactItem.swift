import Foundation
import Contacts

struct ContactItem: Identifiable, Hashable, @unchecked Sendable {
    let id: String
    let contact: CNContact
    let givenName: String
    let familyName: String
    let phoneNumbers: [String]
    let emailAddresses: [String]
    
    init(contact: CNContact) {
        self.id = contact.identifier
        self.contact = contact
        self.givenName = contact.givenName
        self.familyName = contact.familyName
        self.phoneNumbers = contact.phoneNumbers.map { $0.value.stringValue }
        self.emailAddresses = contact.emailAddresses.map { $0.value as String }
    }
    
    var fullName: String {
        let name = "\(givenName) \(familyName)".trimmingCharacters(in: .whitespacesAndNewlines)
        if name.isEmpty {
            if let firstPhone = phoneNumbers.first {
                return firstPhone
            }
            if let firstEmail = emailAddresses.first {
                return firstEmail
            }
            return "Unnamed Contact"
        }
        return name
    }
    
    var primaryDetail: String {
        if let phone = phoneNumbers.first {
            return phone
        }
        if let email = emailAddresses.first {
            return email
        }
        return "No phone or email"
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: ContactItem, rhs: ContactItem) -> Bool {
        lhs.id == rhs.id
    }
}
