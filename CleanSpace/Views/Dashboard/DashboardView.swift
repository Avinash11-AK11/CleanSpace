import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @ObservedObject private var cleanupManager = CleanupManager.shared
    @ObservedObject private var permissionManager = PermissionManager.shared
    @ObservedObject private var vaultManager = VaultManager.shared
    
    @State private var showPermissionSheet = false
    @State private var showAboutSheet = false
    
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
                        
                        Button {
                            HapticManager.shared.selection()
                            showAboutSheet = true
                        } label: {
                            VStack(spacing: 4) {
                                Text("CleanSpace v1.0.0")
                                    .font(.caption)
                                    .fontWeight(.semibold)
                                    .foregroundColor(AppTheme.subtleGray)
                                Text("Crafted with care by Avinash Chavda")
                                    .font(.caption2)
                                    .foregroundColor(AppTheme.accentEmerald)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.top, 10)
                        }
                        .buttonStyle(PlainButtonStyle())
                        
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
            .sheet(isPresented: $showAboutSheet) {
                AboutAppView()
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
                    RoundedRectangle(cornerRadius: 14, style: .continuous)
                        .fill(AppTheme.emeraldGradient)
                        .frame(width: 48, height: 48)
                    
                    Image(systemName: "hand.draw.fill")
                        .font(.system(size: 22, weight: .semibold))
                        .foregroundColor(.white)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Swipe Photo Cleaner")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
                            .foregroundColor(.primary)
                        Text("QUICK CLEAN")
                            .font(.system(size: 9, weight: .heavy))
                            .foregroundColor(.white)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2.5)
                            .background(AppTheme.accentEmerald)
                            .clipShape(Capsule())
                    }
                    
                    Text("Swipe right to keep, swipe left to delete photos")
                        .font(.system(size: 13))
                        .foregroundColor(AppTheme.subtleGray)
                }
                
                Spacer()
                
                Image(systemName: "chevron.right")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundColor(Color(uiColor: .tertiaryLabel))
            }
            .padding(16)
            .cleanCardStyle(cornerRadius: 20)
        }
        .buttonStyle(BounceButtonStyle())
        .padding(.horizontal)
    }
    
    private var scanActionButton: some View {
        VStack(spacing: 10) {
            if viewModel.isScanning {
                VStack(spacing: 10) {
                    HStack {
                        Image(systemName: "magnifyingglass.circle.fill")
                            .foregroundColor(AppTheme.accentEmerald)
                        Text(viewModel.currentTask)
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.primary)
                            .lineLimit(1)
                        Spacer()
                        Text("\(Int(viewModel.scanProgress * 100))%")
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.accentEmerald)
                    }
                    
                    ProgressView(value: viewModel.scanProgress)
                        .tint(AppTheme.accentEmerald)
                }
                .padding(16)
                .cleanCardStyle(cornerRadius: 18)
                .padding(.horizontal)
            } else {
                Button(action: {
                    HapticManager.shared.impact(.medium)
                    Task {
                        await viewModel.startFullScan()
                    }
                }) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.triangle.2.circlepath")
                            .font(.system(size: 16, weight: .bold))
                        Text("Scan iPhone Storage")
                            .font(.system(size: 16, weight: .bold, design: .rounded))
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
                .cleanCardStyle(cornerRadius: 18)
            }
            .buttonStyle(BounceButtonStyle())
            .padding(.horizontal)
        }
    }
    
    private var toolbarIcons: some View {
        HStack(spacing: 8) {
            Button {
                HapticManager.shared.selection()
                showAboutSheet = true
            } label: {
                ZStack {
                    Circle()
                        .fill(AppTheme.accentEmerald.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: "info.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundColor(AppTheme.accentEmerald)
                }
            }
            
            NavigationLink(destination: VaultView()) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accentPurple.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: vaultManager.isUnlocked ? "lock.open.fill" : "lock.fill")
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(AppTheme.accentPurple)
                }
            }
            
            Button {
                HapticManager.shared.selection()
                showPermissionSheet = true
            } label: {
                ZStack {
                    Circle()
                        .fill(AppTheme.accentBlue.opacity(0.12))
                        .frame(width: 36, height: 36)
                    Image(systemName: "hand.raised.circle")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundColor(AppTheme.accentBlue)
                }
            }
        }
    }
    
    private var floatingReviewBar: some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 2) {
                Text(cleanupManager.formattedTotalSelectedCount)
                    .font(.system(size: 15, weight: .bold, design: .rounded))
                Text("Frees up \(cleanupManager.formattedEstimatedBytes)")
                    .font(.system(size: 12, weight: .semibold))
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
