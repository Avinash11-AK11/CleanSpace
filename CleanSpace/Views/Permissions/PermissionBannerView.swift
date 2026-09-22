import SwiftUI

struct PermissionBannerView: View {
    @ObservedObject var permissionManager = PermissionManager.shared
    
    var body: some View {
        VStack(spacing: 12) {
            if permissionManager.isPhotoLimited {
                HStack(spacing: 12) {
                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.title3)
                        .foregroundColor(AppTheme.accentOrange)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Limited Photo Access")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("CleanSpace can only scan photos you selected.")
                            .font(.caption)
                            .foregroundColor(AppTheme.subtleGray)
                    }
                    
                    Spacer()
                    
                    Button("Manage") {
                        permissionManager.presentLimitedLibraryPicker()
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.accentOrange.opacity(0.15))
                    .foregroundColor(AppTheme.accentOrange)
                    .clipShape(Capsule())
                }
                .padding(14)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            } else if permissionManager.isPhotoDenied || permissionManager.isContactDenied {
                HStack(spacing: 12) {
                    Image(systemName: "lock.shield")
                        .font(.title3)
                        .foregroundColor(AppTheme.accentRed)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Permissions Required")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        Text("Enable Photos or Contacts in Settings for full scanning.")
                            .font(.caption)
                            .foregroundColor(AppTheme.subtleGray)
                    }
                    
                    Spacer()
                    
                    Button("Settings") {
                        permissionManager.openAppSettings()
                    }
                    .font(.caption)
                    .fontWeight(.semibold)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .background(AppTheme.accentRed.opacity(0.15))
                    .foregroundColor(AppTheme.accentRed)
                    .clipShape(Capsule())
                }
                .padding(14)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }
}
