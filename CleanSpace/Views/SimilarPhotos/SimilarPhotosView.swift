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
                    
                    Spacer().frame(height: 100)
                }
                .padding(.top, 8)
            }
            
            // Bottom floating action bar
            if cleanupManager.totalSelectedCount > 0 {
                VStack(spacing: 0) {
                    Divider()
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(cleanupManager.formattedTotalSelectedCount)
                                .font(.subheadline)
                                .fontWeight(.bold)
                            Text("Frees: \(cleanupManager.formattedEstimatedBytes)")
                                .font(.caption)
                                .foregroundColor(AppTheme.accentEmerald)
                        }
                        Spacer()
                        NavigationLink(destination: ReviewView()) {
                            Text("Review Cleanup")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 10)
                                .background(AppTheme.accentEmerald)
                                .clipShape(Capsule())
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 14)
                    .background(.ultraThinMaterial)
                }
            }
        }
        .background(AppTheme.primaryBackground)
        .navigationTitle("Photos")
        .navigationBarTitleDisplayMode(.inline)
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
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text("Best photo in each group marked with ⭐")
                        .font(.caption)
                        .foregroundColor(AppTheme.subtleGray)
                }
                
                Spacer()
                
                Button("Auto-Select Extras") {
                    withAnimation {
                        cleanupManager.selectAllDuplicatesExcludingBest(groups: groups)
                    }
                }
                .font(.caption)
                .fontWeight(.semibold)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(AppTheme.accentBlue.opacity(0.12))
                .foregroundColor(AppTheme.accentBlue)
                .clipShape(Capsule())
            }
            .padding(.horizontal)
            
            // Groups List
            LazyVStack(spacing: 16) {
                ForEach(groups) { group in
                    PhotoGroupCard(group: group)
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
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
