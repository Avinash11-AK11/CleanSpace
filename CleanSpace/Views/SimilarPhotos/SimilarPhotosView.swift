import SwiftUI
import Photos

struct SimilarPhotosView: View {
    @Binding var groups: [PhotoGroup]
    @Binding var allPhotos: [PhotoItem]
    
    @ObservedObject private var cleanupManager = CleanupManager.shared
    @State private var selectedTab: PhotoTab = .similar
    
    enum PhotoTab: String, CaseIterable, Identifiable {
        case similar = "Similar"
        case allPhotos = "All Photos"
        var id: String { rawValue }
    }
    
    @State private var inspectingPhoto: PhotoItem? = nil
    
    init(groups: Binding<[PhotoGroup]>, allPhotos: Binding<[PhotoItem]>) {
        self._groups = groups
        self._allPhotos = allPhotos
        _selectedTab = State(initialValue: groups.wrappedValue.isEmpty ? .allPhotos : .similar)
    }
    
    // Set of IDs that belong to a similar / duplicate group
    private var duplicatePhotoIds: Set<String> {
        Set(groups.flatMap { $0.photos.map { $0.id } })
    }
    
    private let gridColumns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    var allPhotosSelected: Bool {
        guard !allPhotos.isEmpty else { return false }
        return allPhotos.allSatisfy { cleanupManager.selectedPhotoIds.contains($0.id) }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 16) {
                    // Top Segmented Picker
                    Picker("Photo View", selection: $selectedTab) {
                        Text("Similar (\(groups.count))").tag(PhotoTab.similar)
                        Text("All Photos (\(allPhotos.count))").tag(PhotoTab.allPhotos)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)
                    .padding(.top, 4)
                    
                    if selectedTab == .similar {
                        similarTabContent
                    } else {
                        allPhotosTabContent
                    }
                    
                    Spacer().frame(height: 110)
                }
                .padding(.top, 8)
            }
            
            // Floating glass action bar
            if cleanupManager.totalSelectedCount > 0 {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cleanupManager.formattedTotalSelectedCount)
                            .font(.system(size: 15, weight: .bold, design: .rounded))
                        Text("Frees: \(cleanupManager.formattedEstimatedBytes)")
                            .font(.system(size: 12, weight: .semibold))
                            .foregroundColor(AppTheme.accentEmerald)
                    }
                    Spacer()
                    NavigationLink(destination: ReviewView()) {
                        HStack(spacing: 6) {
                            Text("Review Cleanup")
                            Image(systemName: "arrow.right")
                        }
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 11)
                        .background(AppTheme.emeraldGradient)
                        .clipShape(Capsule())
                        .shadow(color: AppTheme.accentEmerald.opacity(0.35), radius: 6, x: 0, y: 3)
                    }
                    .buttonStyle(BounceButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 12)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
                .transition(.move(edge: .bottom).combined(with: .opacity))
            }
        }
        .background(AppTheme.primaryBackground)
        .navigationTitle("Photos")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $inspectingPhoto) { photo in
            PhotoDetailInspectorSheet(photo: photo)
        }
        .onAppear {
            syncDeletedPhotos()
        }
        .onChange(of: cleanupManager.deletedAssetIds) {
            syncDeletedPhotos()
        }
    }
    
    // MARK: - Similar / Duplicate Tab
    @ViewBuilder
    private var similarTabContent: some View {
        if groups.isEmpty {
            VStack(spacing: 16) {
                Spacer().frame(height: 60)
                Image(systemName: "sparkles")
                    .font(.system(size: 60))
                    .foregroundColor(AppTheme.accentEmerald)
                Text("No Similar Photos Found")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("Your library has no redundant or duplicate shots!")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.subtleGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                Button("View All Photos") {
                    withAnimation {
                        selectedTab = .allPhotos
                    }
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .padding(.horizontal, 18)
                .padding(.vertical, 10)
                .background(AppTheme.accentBlue.opacity(0.12))
                .foregroundColor(AppTheme.accentBlue)
                .clipShape(Capsule())
                .padding(.top, 8)
            }
            .padding()
        } else {
            // Quick Action Card
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(groups.count == 1 ? "1 Group Identified" : "\(groups.count) Groups Identified")
                        .font(.system(size: 15, weight: .bold, design: .rounded))
                    Text("Best photo in each group marked with ⭐")
                        .font(.caption)
                        .foregroundColor(AppTheme.subtleGray)
                }
                
                Spacer()
                
                Button {
                    HapticManager.shared.impact(.medium)
                    withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                        cleanupManager.selectAllDuplicatesExcludingBest(groups: groups)
                    }
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "wand.and.stars")
                            .font(.system(size: 12, weight: .bold))
                        Text("Auto-Select Extras")
                            .font(.system(size: 12, weight: .bold, design: .rounded))
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .background(AppTheme.accentBlue.opacity(0.14))
                    .foregroundColor(AppTheme.accentBlue)
                    .clipShape(Capsule())
                }
                .buttonStyle(BounceButtonStyle())
            }
            .padding(.horizontal)
            
            // Groups List
            LazyVStack(spacing: 16) {
                ForEach(groups) { group in
                    PhotoGroupCard(group: group, onInspect: { inspectingPhoto = $0 })
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - All Photos Tab
    @ViewBuilder
    private var allPhotosTabContent: some View {
        if allPhotos.isEmpty {
            VStack(spacing: 16) {
                Spacer().frame(height: 60)
                Image(systemName: "photo.stack")
                    .font(.system(size: 60))
                    .foregroundColor(AppTheme.accentEmerald)
                Text("No Photos Found")
                    .font(.title3)
                    .fontWeight(.bold)
                Text("Your photo library is empty.")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.subtleGray)
            }
            .padding()
        } else {
            // Quick Action Header
            HStack {
                Text(allPhotos.count == 1 ? "1 Photo" : "\(allPhotos.count) Photos")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.subtleGray)
                
                Spacer()
                
                Button(allPhotosSelected ? "Deselect All" : "Select All") {
                    withAnimation {
                        if allPhotosSelected {
                            cleanupManager.deselectAllPhotos()
                        } else {
                            cleanupManager.selectAllPhotos(allPhotos)
                        }
                    }
                }
                .font(.subheadline)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.accentBlue)
            }
            .padding(.horizontal)
            
            // 3-Column Grid
            LazyVGrid(columns: gridColumns, spacing: 8) {
                ForEach(allPhotos) { item in
                    let isSelected = cleanupManager.selectedPhotoIds.contains(item.id)
                    let isDuplicate = duplicatePhotoIds.contains(item.id)
                    
                    Button {
                        withAnimation(.spring(response: 0.3)) {
                            cleanupManager.togglePhoto(item)
                        }
                    } label: {
                        ZStack(alignment: .topTrailing) {
                            PHAssetThumbnailView(asset: item.asset)
                                .aspectRatio(1, contentMode: .fill)
                                .clipped()
                                .cornerRadius(12)
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(isSelected ? AppTheme.accentEmerald : Color.clear, lineWidth: 3)
                                )
                            
                            // Top left: Duplicate tag if applicable
                            if isDuplicate {
                                VStack {
                                    HStack {
                                        Text("Similar")
                                            .font(.system(size: 8, weight: .bold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 2)
                                            .background(AppTheme.accentBlue)
                                            .clipShape(Capsule())
                                        Spacer()
                                    }
                                    Spacer()
                                }
                                .padding(4)
                            }
                            
                            // Top right: Selection checkmark
                            ZStack {
                                Circle()
                                    .fill(isSelected ? AppTheme.accentEmerald : Color.black.opacity(0.4))
                                    .frame(width: 24, height: 24)
                                
                                Image(systemName: isSelected ? "checkmark" : "circle")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(.white)
                            }
                            .padding(6)
                            
                            // Bottom right: Quick inspect button
                            VStack {
                                Spacer()
                                HStack {
                                    Spacer()
                                    Button {
                                        HapticManager.shared.impact(.light)
                                        inspectingPhoto = item
                                    } label: {
                                        ZStack {
                                            Circle()
                                                .fill(Color.black.opacity(0.55))
                                                .frame(width: 24, height: 24)
                                            Image(systemName: "arrow.up.left.and.arrow.down.right")
                                                .font(.system(size: 9, weight: .bold))
                                                .foregroundColor(.white)
                                        }
                                    }
                                }
                                .padding(4)
                            }
                            
                            // Bottom left: File Size tag
                            VStack {
                                Spacer()
                                HStack {
                                    Text(item.formattedSize)
                                        .font(.system(size: 9, weight: .semibold))
                                        .foregroundColor(.white)
                                        .padding(.horizontal, 5)
                                        .padding(.vertical, 2)
                                        .background(Color.black.opacity(0.6))
                                        .clipShape(Capsule())
                                    Spacer()
                                }
                                .padding(4)
                            }
                        }
                    }
                    .buttonStyle(PlainButtonStyle())
                }
            }
            .padding(.horizontal, 12)
        }
    }
    
    // MARK: - Synchronize Deleted Photos
    private func syncDeletedPhotos() {
        guard !cleanupManager.deletedAssetIds.isEmpty else { return }
        withAnimation {
            allPhotos.removeAll { cleanupManager.deletedAssetIds.contains($0.id) }
            
            var updatedGroups: [PhotoGroup] = []
            for group in groups {
                let remaining = group.photos.filter { !cleanupManager.deletedAssetIds.contains($0.id) }
                if remaining.count >= 2 {
                    var updated = group
                    updated.photos = remaining
                    if let best = updated.recommendedBestId, !remaining.contains(where: { $0.id == best }) {
                        updated.recommendedBestId = remaining.first?.id
                    }
                    updatedGroups.append(updated)
                }
            }
            groups = updatedGroups
        }
    }
}

// MARK: - Photo Group Card
struct PhotoGroupCard: View {
    let group: PhotoGroup
    var onInspect: ((PhotoItem) -> Void)? = nil
    @ObservedObject private var cleanupManager = CleanupManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("\(group.photos.count) Photos")
                    .font(.caption)
                    .fontWeight(.bold)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(uiColor: .systemFill))
                    .clipShape(Capsule())
                
                Spacer()
                
                Text("Potential: \(group.formattedCleanableSize)")
                    .font(.caption)
                    .foregroundColor(AppTheme.accentEmerald)
                    .fontWeight(.semibold)
            }
            
            // Horizontal photo scroll
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(group.photos) { photo in
                        let isBest = photo.id == group.recommendedBestId
                        let isSelected = cleanupManager.selectedPhotoIds.contains(photo.id)
                        
                        Button {
                            HapticManager.shared.selection()
                            withAnimation(.spring(response: 0.3)) {
                                cleanupManager.togglePhoto(photo)
                            }
                        } label: {
                            ZStack(alignment: .topTrailing) {
                                PHAssetThumbnailView(asset: photo.asset)
                                    .frame(width: 110, height: 110)
                                    .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12, style: .continuous)
                                            .stroke(
                                                isSelected ? AppTheme.accentEmerald : Color.clear,
                                                lineWidth: 3
                                            )
                                    )
                                
                                // Star badge for recommended best
                                if isBest {
                                    VStack {
                                        HStack {
                                            HStack(spacing: 2) {
                                                Image(systemName: "star.fill")
                                                    .font(.system(size: 8))
                                                Text("Best")
                                                    .font(.system(size: 9, weight: .bold))
                                            }
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 2)
                                            .background(AppTheme.accentOrange)
                                            .foregroundColor(.white)
                                            .clipShape(Capsule())
                                            Spacer()
                                        }
                                        Spacer()
                                    }
                                    .padding(4)
                                }
                                
                                // Checkmark selection circle
                                ZStack {
                                    Circle()
                                        .fill(isSelected ? AppTheme.accentEmerald : Color.black.opacity(0.4))
                                        .frame(width: 22, height: 22)
                                    
                                    Image(systemName: isSelected ? "checkmark" : "circle")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundColor(.white)
                                }
                                .padding(6)
                                
                                // Bottom right: Expand button
                                VStack {
                                    Spacer()
                                    HStack {
                                        Spacer()
                                        Button {
                                            HapticManager.shared.impact(.light)
                                            onInspect?(photo)
                                        } label: {
                                            ZStack {
                                                Circle()
                                                    .fill(Color.black.opacity(0.55))
                                                    .frame(width: 22, height: 22)
                                                Image(systemName: "arrow.up.left.and.arrow.down.right")
                                                    .font(.system(size: 8, weight: .bold))
                                                    .foregroundColor(.white)
                                            }
                                        }
                                    }
                                    .padding(4)
                                }
                                
                                // Size tag
                                VStack {
                                    Spacer()
                                    HStack {
                                        Text(photo.formattedSize)
                                            .font(.system(size: 9, weight: .semibold))
                                            .foregroundColor(.white)
                                            .padding(.horizontal, 4)
                                            .padding(.vertical, 1)
                                            .background(Color.black.opacity(0.6))
                                            .clipShape(Capsule())
                                        Spacer()
                                    }
                                    .padding(4)
                                }
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                }
            }
        }
        .padding(14)
        .cleanCardStyle(cornerRadius: 18)
    }
}

// MARK: - Photo Detail Inspector Sheet
struct PhotoDetailInspectorSheet: View {
    let photo: PhotoItem
    @ObservedObject private var cleanupManager = CleanupManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    PHAssetThumbnailView(asset: photo.asset)
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    VStack(spacing: 14) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(photo.formattedSize)
                                    .font(.headline)
                                    .foregroundColor(.white)
                                Text("\(photo.asset.pixelWidth) × \(photo.asset.pixelHeight) • \(photo.asset.creationDate?.formatted(date: .abbreviated, time: .shortened) ?? "Photo")")
                                    .font(.caption)
                                    .foregroundColor(.gray)
                            }
                            Spacer()
                            
                            let isSelected = cleanupManager.selectedPhotoIds.contains(photo.id)
                            Button {
                                HapticManager.shared.impact(.light)
                                withAnimation {
                                    cleanupManager.togglePhoto(photo)
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    Text(isSelected ? "Marked for Delete" : "Keep Photo")
                                }
                                .font(.subheadline.bold())
                                .foregroundColor(isSelected ? AppTheme.accentRed : AppTheme.accentEmerald)
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .background(Color.white.opacity(0.15))
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 16)
                    }
                    .background(Color.black.opacity(0.85))
                }
            }
            .navigationTitle("Inspect Photo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.body.bold())
                    .foregroundColor(AppTheme.accentEmerald)
                }
            }
        }
    }
}
