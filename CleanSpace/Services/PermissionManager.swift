import Foundation
import Photos
import Contacts
import UIKit
import PhotosUI

@MainActor
final class PermissionManager: ObservableObject {
    static let shared = PermissionManager()
    
    @Published var photoStatus: PHAuthorizationStatus
    @Published var contactStatus: CNAuthorizationStatus
    
    init() {
        self.photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        self.contactStatus = CNContactStore.authorizationStatus(for: .contacts)
    }
    
    func refreshStatuses() {
        photoStatus = PHPhotoLibrary.authorizationStatus(for: .readWrite)
        contactStatus = CNContactStore.authorizationStatus(for: .contacts)
    }
    
    var hasPhotoAccess: Bool {
        photoStatus == .authorized || photoStatus == .limited
    }
    
    var isPhotoLimited: Bool {
        photoStatus == .limited
    }
    
    var isPhotoDenied: Bool {
        photoStatus == .denied || photoStatus == .restricted
    }
    
    var hasContactAccess: Bool {
        contactStatus == .authorized
    }
    
    var isContactDenied: Bool {
        contactStatus == .denied || contactStatus == .restricted
    }
    
    func requestPhotoAccess() async -> PHAuthorizationStatus {
        let status = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        self.photoStatus = status
        return status
    }
    
    func requestContactAccess() async -> Bool {
        let store = CNContactStore()
        do {
            let granted = try await store.requestAccess(for: .contacts)
            self.contactStatus = granted ? .authorized : .denied
            return granted
        } catch {
            self.contactStatus = .denied
            return false
        }
    }
    
    func openAppSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        if UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url)
        }
    }
    
    func presentLimitedLibraryPicker() {
        guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
              let rootVC = windowScene.windows.first?.rootViewController else { return }
        PHPhotoLibrary.shared().presentLimitedLibraryPicker(from: rootVC)
    }
}
