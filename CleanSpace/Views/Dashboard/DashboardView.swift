import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @ObservedObject private var cleanupManager = CleanupManager.shared
    @ObservedObject private var permissionManager = PermissionManager.shared
    @ObservedObject private var vaultManager = VaultManager.shared
    
    @State private var showPermissionSheet = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 20) {
                        PermissionBannerView()
                            .padding(.horizontal)
                        
                        StorageGaugeView(
                            storageInfo: viewModel.storageInfo,
                            cleanableBytes: viewModel.totalCleanableBytes
                        )
                        .padding(.horizontal)
                        
                        swipeCleanerHeroCard
                        
                        scanActionButton
                        
                        cleanupCategoriesSection
                        
                        securitySection

                        
                        Spacer().frame(height: 100)
                    }
                    .padding(.top, 10)
                }
                .background(AppTheme.primaryBackground)
                .navigationTitle("CleanSpace")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        toolbarIcons
                    }
                }
                
                if cleanupManager.totalSelectedCount > 0 {
                    floatingReviewBar
                }
            }
            .task {
                permissionManager.refreshStatuses()
                if !permissionManager.hasPhotoAccess {
                    showPermissionSheet = true
                } else {
                    await viewModel.startFullScan()
                }
            }
            .sheet(isPresented: $showPermissionSheet) {
                PermissionRequestSheet {
                    permissionManager.refreshStatuses()
                    Task {
                        await viewModel.startFullScan()
                    }
                }
                .presentationDetents([.fraction(0.7)])
            }
            .onChange(of: cleanupManager.deletedAssetIds) {
                Task {
                    viewModel.refreshStorage()
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var swipeCleanerHeroCard: some View {
        NavigationLink(destination: SwipeCleanerView(photos: viewModel.allPhotos)) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(LinearGradient(colors: [AppTheme.accentEmerald, AppTheme.accentBlue], startPoint: .topLeading, endPoint: .bottomTrailing))
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 22))
                        .foregroundColor(.primary)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text("Swipe Photo Cleaner")
                            .font(.headline)
                            .foregroundColor(.primary)
                        Text("QUICK CLEAN")
                            .font(.system(size: 9, weight: .bold))
                            .foregroundColor(.black)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(AppTheme.accentEmerald)
                            .clipShape(Capsule())
                    }
                    
                    Text("Swipe right to keep, swipe left to delete photos")
                        .font(.caption)
                        .foregroundColor(AppTheme.subtleGray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.caption.bold())
                    .foregroundColor(AppTheme.subtleGray)
            }
            .padding(16)
            .background(AppTheme.cardBackground)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(AppTheme.accentEmerald.opacity(0.3), lineWidth: 1)
            )
        }
        .buttonStyle(PlainButtonStyle())
        .padding(.horizontal)
    }
    
    private var scanActionButton: some View {
        VStack(spacing: 10) {
            if viewModel.isScanning {
                VStack(spacing: 10) {
                    ProgressView(value: viewModel.scanProgress)
                        .tint(AppTheme.accentEmerald)
                    HStack {
                        Text(viewModel.currentTask)
                            .font(.caption)
                            .foregroundColor(AppTheme.subtleGray)
                        Spacer()
                        Text("\(Int(viewModel.scanProgress * 100))%")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundColor(AppTheme.accentEmerald)
                    }
                }
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
            } else {
                Button(action: {
                    Task {
                        await viewModel.startFullScan()
                    }
                }) {
                    HStack {
                        Image(systemName: "arrow.triangle.2.circlepath")
                        Text("Scan iPhone Storage")
                    }
                }
                .primaryButtonStyle(bg: AppTheme.accentEmerald)
                .padding(.horizontal)
            }
        }
    }
    
    private var cleanupCategoriesSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("CLEANUP CATEGORIES")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.subtleGray)
                .tracking(1.0)
                .padding(.horizontal)
            
            // 1. Photos & Duplicates
            NavigationLink(destination: SimilarPhotosView(groups: $viewModel.similarPhotoGroups, allPhotos: $viewModel.allPhotos)) {
                let pCount = viewModel.allPhotos.count
                let pText = pCount == 1 ? "1 photo" : "\(pCount) photos"
                let pgCount = viewModel.similarPhotoGroups.count
                let pgText = pgCount == 1 ? "1 duplicate group" : "\(pgCount) duplicate groups"
                CategoryCardView(
                    title: "Photos & Duplicates",
                    subtitle: pgCount == 0 ? pText : "\(pText) • \(pgText)",
                    badgeText: viewModel.cleanablePhotoBytes > 0 ? ByteCountFormatter.string(fromByteCount: viewModel.cleanablePhotoBytes, countStyle: .file) : nil,
                    iconName: "photo.on.rectangle.angled",
                    iconColor: AppTheme.accentBlue
                )
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)
            
            // 2. Blurry Photos
            NavigationLink(destination: BlurryPhotosView(blurryPhotos: $viewModel.blurryPhotos)) {
                let bCount = viewModel.blurryPhotos.count
                CategoryCardView(
                    title: "Blurry Photos",
                    subtitle: bCount == 1 ? "1 blurry photo found" : "\(bCount) blurry photos found",
                    badgeText: viewModel.cleanableBlurryBytes > 0 ? ByteCountFormatter.string(fromByteCount: viewModel.cleanableBlurryBytes, countStyle: .file) : nil,
                    iconName: "aqi.medium",
                    iconColor: Color.yellow
                )
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)
            
            // 3. Screenshots
            NavigationLink(destination: ScreenshotsView(screenshots: $viewModel.screenshots)) {
                let sCount = viewModel.screenshots.count
                CategoryCardView(
                    title: "Screenshots",
                    subtitle: sCount == 1 ? "1 screenshot" : "\(sCount) screenshots",
                    badgeText: viewModel.cleanableScreenshotBytes > 0 ? ByteCountFormatter.string(fromByteCount: viewModel.cleanableScreenshotBytes, countStyle: .file) : nil,
                    iconName: "camera.viewfinder",
                    iconColor: AppTheme.accentPurple
                )
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)
            
            // 4. Videos & Duplicates
            NavigationLink(destination: LargeVideosView(videos: $viewModel.largeVideos, duplicateGroups: $viewModel.duplicateVideoGroups)) {
                let vCount = viewModel.largeVideos.count
                let vText = vCount == 1 ? "1 video" : "\(vCount) videos"
                let gCount = viewModel.duplicateVideoGroups.count
                let gText = gCount == 1 ? "1 duplicate group" : "\(gCount) duplicate groups"
                let badge = viewModel.cleanableDuplicateVideoBytes > 0 ? ByteCountFormatter.string(fromByteCount: viewModel.cleanableDuplicateVideoBytes, countStyle: .file) : (viewModel.cleanableVideoBytes > 0 ? ByteCountFormatter.string(fromByteCount: viewModel.cleanableVideoBytes, countStyle: .file) : nil)
                CategoryCardView(
                    title: "Videos & Compression",
                    subtitle: gCount == 0 ? vText : "\(vText) • \(gText)",
                    badgeText: badge,
                    iconName: "film.stack",
                    iconColor: AppTheme.accentOrange
                )
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)
            
            // 5. Duplicate Contacts
            NavigationLink(destination: DuplicateContactsView(groups: $viewModel.duplicateContactGroups)) {
                let cCount = viewModel.duplicateContactGroups.count
                CategoryCardView(
                    title: "Duplicate Contacts",
                    subtitle: cCount == 1 ? "1 duplicate contact" : "\(cCount) duplicate contacts",
                    badgeText: "\(viewModel.duplicateContactGroups.count)",
                    iconName: "person.crop.circle.badge.exclamationmark",
                    iconColor: AppTheme.accentEmerald
                )
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)
            
            // 6. Calendar Cleanup
            NavigationLink(destination: CalendarCleanupView()) {
                CategoryCardView(
                    title: "Calendar Cleanup",
                    subtitle: "Remove expired past events and spam invites",
                    badgeText: "Manage",
                    iconName: "calendar.badge.clock",
                    iconColor: Color.red
                )
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)
        }
    }
    
    private var securitySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("SECURITY & PRIVACY")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.subtleGray)
                .tracking(1.0)
                .padding(.horizontal)
            
            NavigationLink(destination: VaultView()) {
                HStack(spacing: 16) {
                    ZStack {
                        Circle()
                            .fill(AppTheme.accentPurple.opacity(0.18))
                            .frame(width: 44, height: 44)
                        
                        Image(systemName: "lock.shield.fill")
                            .font(.system(size: 20))
                            .foregroundColor(AppTheme.accentPurple)
                    }
                    
                    VStack(alignment: .leading, spacing: 3) {
                        HStack {
                            Text("Secret Photo Vault")
                                .font(.headline)
                                .foregroundColor(.primary)
                            if vaultManager.isUnlocked {
                                Text("UNLOCKED")
                                    .font(.system(size: 8, weight: .bold))
                                    .foregroundColor(AppTheme.accentEmerald)
                            }
                        }
                        
                        Text("Encrypted storage protected by PIN or Face ID")
                            .font(.caption)
                            .foregroundColor(AppTheme.subtleGray)
                    }
                    
                    Spacer()
                    
                    Image(systemName: "chevron.right")
                        .font(.caption.bold())
                        .foregroundColor(AppTheme.subtleGray)
                }
                .padding(16)
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .buttonStyle(PlainButtonStyle())
            .padding(.horizontal)
        }
    }
    
    private var toolbarIcons: some View {
        HStack(spacing: 12) {
            NavigationLink(destination: VaultView()) {
                Image(systemName: vaultManager.isUnlocked ? "lock.open.fill" : "lock.fill")
                    .foregroundColor(AppTheme.accentPurple)
            }
            
            Button {
                showPermissionSheet = true
            } label: {
                Image(systemName: "hand.raised.circle")
                    .foregroundColor(AppTheme.accentBlue)
            }
        }
    }
    
    private var floatingReviewBar: some View {
        VStack(spacing: 0) {
            Divider()
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(cleanupManager.formattedTotalSelectedCount)
                        .font(.subheadline)
                        .fontWeight(.bold)
                    Text("Frees up \(cleanupManager.formattedEstimatedBytes)")
                        .font(.caption)
                        .foregroundColor(AppTheme.accentEmerald)
                }
                
                Spacer()
                
                NavigationLink(destination: ReviewView {
                    Task {
                        await viewModel.startFullScan()
                    }
                }) {
                    HStack(spacing: 6) {
                        Text("Review & Clean")
                        Image(systemName: "arrow.right")
                    }
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
        .transition(.move(edge: .bottom).combined(with: .opacity))
    }
}
