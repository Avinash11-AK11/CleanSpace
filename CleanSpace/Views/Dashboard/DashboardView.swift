import SwiftUI

struct DashboardView: View {
    @StateObject private var viewModel = DashboardViewModel()
    @ObservedObject private var cleanupManager = CleanupManager.shared
    @ObservedObject private var permissionManager = PermissionManager.shared
    
    @State private var showPermissionSheet = false
    @State private var navigateToReview = false
    
    var body: some View {
        NavigationStack {
            ZStack(alignment: .bottom) {
                ScrollView {
                    VStack(spacing: 20) {
                        // Permission warning banner if limited or denied
                        PermissionBannerView()
                            .padding(.horizontal)
                        
                        // Storage Gauge Card
                        StorageGaugeView(
                            storageInfo: viewModel.storageInfo,
                            cleanableBytes: viewModel.totalCleanableBytes
                        )
                        .padding(.horizontal)
                        
                        // Scan Action Button / Status
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
                        
                        // Categories Section
                        VStack(alignment: .leading, spacing: 14) {
                            Text("CLEANUP CATEGORIES")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(AppTheme.subtleGray)
                                .tracking(1.0)
                                .padding(.horizontal)
                            
                            // 1. Similar Photos
                            NavigationLink(destination: SimilarPhotosView(groups: $viewModel.similarPhotoGroups)) {
                                CategoryCardView(
                                    title: "Similar & Duplicate Photos",
                                    subtitle: "\(viewModel.similarPhotoGroups.count) groups found",
                                    badgeText: viewModel.cleanablePhotoBytes > 0 ? ByteCountFormatter.string(fromByteCount: viewModel.cleanablePhotoBytes, countStyle: .file) : nil,
                                    iconName: "photo.on.rectangle.angled",
                                    iconColor: AppTheme.accentBlue
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                            
                            // 2. Screenshots
                            NavigationLink(destination: ScreenshotsView(screenshots: viewModel.screenshots)) {
                                CategoryCardView(
                                    title: "Screenshots",
                                    subtitle: "\(viewModel.screenshots.count) items",
                                    badgeText: viewModel.cleanableScreenshotBytes > 0 ? ByteCountFormatter.string(fromByteCount: viewModel.cleanableScreenshotBytes, countStyle: .file) : nil,
                                    iconName: "camera.viewfinder",
                                    iconColor: AppTheme.accentPurple
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                            
                            // 3. Large Videos
                            NavigationLink(destination: LargeVideosView(videos: viewModel.largeVideos)) {
                                CategoryCardView(
                                    title: "Large Videos",
                                    subtitle: "\(viewModel.largeVideos.count) videos",
                                    badgeText: viewModel.cleanableVideoBytes > 0 ? ByteCountFormatter.string(fromByteCount: viewModel.cleanableVideoBytes, countStyle: .file) : nil,
                                    iconName: "film.stack",
                                    iconColor: AppTheme.accentOrange
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                            
                            // 4. Duplicate Contacts
                            NavigationLink(destination: DuplicateContactsView(groups: viewModel.duplicateContactGroups)) {
                                CategoryCardView(
                                    title: "Duplicate Contacts",
                                    subtitle: "\(viewModel.duplicateContactGroups.count) potential duplicates",
                                    badgeText: "\(viewModel.duplicateContactGroups.count)",
                                    iconName: "person.crop.circle.badge.exclamationmark",
                                    iconColor: AppTheme.accentEmerald
                                )
                            }
                            .buttonStyle(PlainButtonStyle())
                            .padding(.horizontal)
                        }
                        
                        Spacer().frame(height: 100) // Padding for floating review bar
                    }
                    .padding(.top, 10)
                }
                .background(AppTheme.primaryBackground)
                .navigationTitle("CleanSpace")
                .navigationBarTitleDisplayMode(.large)
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            showPermissionSheet = true
                        } label: {
                            Image(systemName: "hand.raised.circle")
                                .foregroundColor(AppTheme.accentBlue)
                        }
                    }
                }
                
                // Floating Bottom Review Bar
                if cleanupManager.totalSelectedCount > 0 {
                    VStack(spacing: 0) {
                        Divider()
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(cleanupManager.totalSelectedCount) items selected")
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
        }
    }
}
