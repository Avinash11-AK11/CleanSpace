import SwiftUI
import Photos
import Contacts

struct ReviewView: View {
    @ObservedObject private var cleanupManager = CleanupManager.shared
    @Environment(\.dismiss) private var dismiss
    var onCleanupFinished: (() -> Void)? = nil
    
    @State private var showConfirmDialog = false
    @State private var isDeleting = false
    @State private var deletionProgress: Double = 0.0
    @State private var deletionStatus: String = ""
    @State private var navigateToSpaceFreed = false
    @State private var errorMessage: String?
    @State private var showErrorAlert = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 24) {
                    // Header Banner
                    VStack(spacing: 8) {
                        Image(systemName: "shield.lefthalf.filled.badge.checkmark")
                            .font(.system(size: 48))
                            .foregroundColor(AppTheme.accentEmerald)
                            .padding(.top, 12)
                        
                        Text("Review Before Clean")
                            .font(.title2)
                            .fontWeight(.bold)
                        
                        Text("Nothing is deleted without your explicit consent. Verify all items below before proceeding.")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.subtleGray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    
                    // Space Summary Card
                    VStack(spacing: 12) {
                        Text("ESTIMATED SPACE TO RECOVER")
                            .font(.caption2)
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.subtleGray)
                            .tracking(1.0)
                        
                        Text(cleanupManager.formattedEstimatedBytes)
                            .font(.system(size: 40, weight: .heavy, design: .rounded))
                            .foregroundColor(AppTheme.accentEmerald)
                        
                        Text("Across \(cleanupManager.totalSelectedCount) selected items")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.subtleGray)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(20)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 20, style: .continuous))
                    .padding(.horizontal)
                    
                    // Breakdown List
                    VStack(alignment: .leading, spacing: 14) {
                        Text("SELECTED ITEMS BREAKDOWN")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.subtleGray)
                            .tracking(1.0)
                            .padding(.horizontal)
                        
                        // Similar Photos
                        if !cleanupManager.selectedPhotoIds.isEmpty {
                            ReviewCategoryRow(
                                title: "Similar Photos",
                                count: cleanupManager.selectedPhotoIds.count,
                                sizeText: ByteCountFormatter.string(fromByteCount: cleanupManager.selectedPhotoIds.compactMap { cleanupManager.allPhotosMap[$0]?.fileSize }.reduce(0, +), countStyle: .file),
                                icon: "photo.on.rectangle.angled",
                                iconColor: AppTheme.accentBlue
                            ) {
                                cleanupManager.selectedPhotoIds.removeAll()
                            }
                        }
                        
                        // Screenshots
                        if !cleanupManager.selectedScreenshotIds.isEmpty {
                            ReviewCategoryRow(
                                title: "Screenshots",
                                count: cleanupManager.selectedScreenshotIds.count,
                                sizeText: ByteCountFormatter.string(fromByteCount: cleanupManager.selectedScreenshotIds.compactMap { cleanupManager.allScreenshotsMap[$0]?.fileSize }.reduce(0, +), countStyle: .file),
                                icon: "camera.viewfinder",
                                iconColor: AppTheme.accentPurple
                            ) {
                                cleanupManager.selectedScreenshotIds.removeAll()
                            }
                        }
                        
                        // Large & Duplicate Videos
                        if !cleanupManager.selectedVideoIds.isEmpty {
                            ReviewCategoryRow(
                                title: "Videos",
                                count: cleanupManager.selectedVideoIds.count,
                                sizeText: ByteCountFormatter.string(fromByteCount: cleanupManager.selectedVideoIds.compactMap { cleanupManager.allVideosMap[$0]?.fileSize }.reduce(0, +), countStyle: .file),
                                icon: "film.stack",
                                iconColor: AppTheme.accentOrange
                            ) {
                                cleanupManager.selectedVideoIds.removeAll()
                            }
                        }
                        
                        // Duplicate Contacts
                        if !cleanupManager.selectedContactIds.isEmpty {
                            ReviewCategoryRow(
                                title: "Duplicate Contacts",
                                count: cleanupManager.selectedContactIds.count,
                                sizeText: "Address Book",
                                icon: "person.crop.circle.badge.exclamationmark",
                                iconColor: AppTheme.accentEmerald
                            ) {
                                cleanupManager.selectedContactIds.removeAll()
                            }
                        }
                    }
                    .padding(.horizontal)
                    
                    Spacer().frame(height: 120)
                }
            }
            
            // Bottom Action Section
            VStack(spacing: 12) {
                if isDeleting {
                    VStack(spacing: 8) {
                        ProgressView(value: deletionProgress)
                            .tint(AppTheme.accentEmerald)
                        Text(deletionStatus)
                            .font(.caption)
                            .foregroundColor(AppTheme.subtleGray)
                    }
                    .padding()
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .padding(.horizontal)
                } else {
                    Button(action: {
                        showConfirmDialog = true
                    }) {
                        HStack {
                            Image(systemName: "trash.fill")
                            Text("Clean \(cleanupManager.totalSelectedCount) Items")
                        }
                    }
                    .primaryButtonStyle(bg: cleanupManager.totalSelectedCount > 0 ? AppTheme.accentEmerald : Color.gray)
                    .disabled(cleanupManager.totalSelectedCount == 0)
                    .padding(.horizontal, 20)
                }
            }
            .padding(.vertical, 16)
            .background(.ultraThinMaterial)
        }
        .background(AppTheme.primaryBackground)
        .navigationTitle("Review")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Remove Selected Items?",
            isPresented: $showConfirmDialog,
            titleVisibility: .visible
        ) {
            Button("Remove \(cleanupManager.totalSelectedCount) Items from Device", role: .destructive) {
                performCleanup()
            }
            Button("Cancel", role: .cancel) {}
        } message: {
            Text("Photos and videos will be removed from your Photos library via Apple's secure confirmation dialog. Duplicate contacts will be removed from your address book.")
        }
        .alert("Cleanup Error", isPresented: $showErrorAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unexpected error occurred.")
        }
        .navigationDestination(isPresented: $navigateToSpaceFreed) {
            SpaceFreedView {
                onCleanupFinished?()
                dismiss()
            }
        }
    }
    
    private func performCleanup() {
        Task {
            isDeleting = true
            deletionProgress = 0.1
            deletionStatus = "Preparing deletion..."
            
            let photosToDelete = cleanupManager.selectedPhotoIds.compactMap { cleanupManager.allPhotosMap[$0]?.asset }
            let screenshotsToDelete = cleanupManager.selectedScreenshotIds.compactMap { cleanupManager.allScreenshotsMap[$0]?.asset }
            let videosToDelete = cleanupManager.selectedVideoIds.compactMap { cleanupManager.allVideosMap[$0]?.asset }
            let allAssetsToDelete = photosToDelete + screenshotsToDelete + videosToDelete
            
            let contactsToDelete = cleanupManager.selectedContactIds.compactMap { cleanupManager.allContactsMap[$0]?.contact }
            
            let freedPhotoIds = cleanupManager.selectedPhotoIds
            let freedScreenshotIds = cleanupManager.selectedScreenshotIds
            let freedVideoIds = cleanupManager.selectedVideoIds
            let freedContactIds = cleanupManager.selectedContactIds
            let allFreedAssetIds = freedPhotoIds.union(freedScreenshotIds).union(freedVideoIds)
            
            let freedBytes = cleanupManager.totalEstimatedBytes
            let freedCount = cleanupManager.totalSelectedCount
            
            do {
                // Delete photo assets
                if !allAssetsToDelete.isEmpty {
                    deletionStatus = "Removing media from Photos..."
                    deletionProgress = 0.4
                    try await CleanupService.shared.deleteAssets(assets: allAssetsToDelete)
                }
                
                // Delete contacts
                if !contactsToDelete.isEmpty {
                    deletionStatus = "Removing duplicate contacts..."
                    deletionProgress = 0.8
                    try await CleanupService.shared.deleteContacts(contacts: contactsToDelete)
                }
                
                deletionProgress = 1.0
                deletionStatus = "Done!"
                
                // Save freed statistics and notify live tracking
                cleanupManager.lastFreedBytes = freedBytes
                cleanupManager.lastFreedItemCount = freedCount
                cleanupManager.recordDeletedItems(assetIds: allFreedAssetIds, contactIds: freedContactIds)
                cleanupManager.clearAllSelections()
                
                try? await Task.sleep(nanoseconds: 300_000_000)
                isDeleting = false
                navigateToSpaceFreed = true
                
            } catch {
                isDeleting = false
                errorMessage = error.localizedDescription
                showErrorAlert = true
            }
        }
    }
}

struct ReviewCategoryRow: View {
    let title: String
    let count: Int
    let sizeText: String
    let icon: String
    let iconColor: Color
    let onRemove: () -> Void
    
    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(iconColor.opacity(0.15))
                    .frame(width: 40, height: 40)
                Image(systemName: icon)
                    .font(.system(size: 18))
                    .foregroundColor(iconColor)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text("\(count) items • \(sizeText)")
                    .font(.caption)
                    .foregroundColor(AppTheme.subtleGray)
            }
            
            Spacer()
            
            Button(action: onRemove) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundColor(Color(uiColor: .tertiaryLabel))
                    .font(.title3)
            }
        }
        .padding(14)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
