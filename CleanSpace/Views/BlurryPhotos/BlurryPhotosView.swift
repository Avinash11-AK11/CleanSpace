//
//  BlurryPhotosView.swift
//  CleanSpace
//
//  Created by Avinash Chavda on 23/09/2026, 10:55 AM.
//  Copyright © 2026 Avinash Chavda. All rights reserved.
//

import SwiftUI
import Photos

struct BlurryPhotosView: View {
    @Binding var blurryPhotos: [BlurryPhotoItem]
    @ObservedObject private var cleanupManager = CleanupManager.shared
    @State private var inspectingItem: BlurryPhotoItem? = nil
    
    private let columns = [
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8),
        GridItem(.flexible(), spacing: 8)
    ]
    
    var allSelected: Bool {
        guard !blurryPhotos.isEmpty else { return false }
        return blurryPhotos.allSatisfy { cleanupManager.selectedPhotoIds.contains($0.id) }
    }
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 16) {
                    if blurryPhotos.isEmpty {
                        VStack(spacing: 16) {
                            Spacer().frame(height: 60)
                            Image(systemName: "camera.metering.matrix")
                                .font(.system(size: 60))
                                .foregroundColor(AppTheme.accentEmerald)
                            Text("No Blurry Photos Found")
                                .font(.system(size: 20, weight: .bold, design: .rounded))
                            Text("All photos in your library are clear and in focus!")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.subtleGray)
                                .multilineTextAlignment(.center)
                        }
                        .padding()
                    } else {
                        // Quick Action Header
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(blurryPhotos.count == 1 ? "1 Blurry Photo" : "\(blurryPhotos.count) Blurry Photos")
                                    .font(.system(size: 15, weight: .bold, design: .rounded))
                                Text("Detected via optical edge sharpness")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.subtleGray)
                            }
                            
                            Spacer()
                            
                            Button(allSelected ? "Deselect All" : "Select All") {
                                HapticManager.shared.impact(.light)
                                withAnimation {
                                    if allSelected {
                                        for item in blurryPhotos {
                                            cleanupManager.selectedPhotoIds.remove(item.id)
                                        }
                                    } else {
                                        for item in blurryPhotos {
                                            cleanupManager.selectedPhotoIds.insert(item.id)
                                            cleanupManager.allPhotosMap[item.id] = item.photo
                                        }
                                    }
                                }
                            }
                            .font(.system(size: 13, weight: .bold, design: .rounded))
                            .foregroundColor(AppTheme.accentBlue)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(AppTheme.accentBlue.opacity(0.12))
                            .clipShape(Capsule())
                            .buttonStyle(BounceButtonStyle())
                        }
                        .padding(.horizontal)
                        
                        LazyVGrid(columns: columns, spacing: 8) {
                            ForEach(blurryPhotos) { item in
                                let isSelected = cleanupManager.selectedPhotoIds.contains(item.id)
                                
                                Button {
                                    HapticManager.shared.selection()
                                    withAnimation(.spring(response: 0.3)) {
                                        cleanupManager.togglePhoto(item.photo)
                                    }
                                } label: {
                                    ZStack(alignment: .topTrailing) {
                                        PHAssetThumbnailView(asset: item.photo.asset)
                                            .aspectRatio(1, contentMode: .fill)
                                            .clipped()
                                            .cornerRadius(12)
                                            .overlay(
                                                RoundedRectangle(cornerRadius: 12)
                                                    .stroke(isSelected ? AppTheme.accentEmerald : Color.clear, lineWidth: 3)
                                            )
                                        
                                        // Blurry Score Tag at Top Left
                                        VStack {
                                            HStack {
                                                HStack(spacing: 3) {
                                                    Image(systemName: "eye.slash.fill")
                                                        .font(.system(size: 8))
                                                    Text(item.formattedSharpness)
                                                        .font(.system(size: 8, weight: .bold))
                                                }
                                                .foregroundColor(.white)
                                                .padding(.horizontal, 5)
                                                .padding(.vertical, 2)
                                                .background(AppTheme.accentOrange.opacity(0.95))
                                                .clipShape(Capsule())
                                                
                                                Spacer()
                                            }
                                            Spacer()
                                        }
                                        .padding(4)
                                        
                                        // Selection checkmark at Top Right
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
                                                    inspectingItem = item
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
                                        
                                        // File Size tag at Bottom Left
                                        VStack {
                                            Spacer()
                                            HStack {
                                                Text(item.photo.formattedSize)
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
                    
                    Spacer().frame(height: 110)
                }
                .padding(.top, 8)
            }
            
            // Bottom floating action bar
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
        .navigationTitle("Blurry Photos")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $inspectingItem) { item in
            BlurryPhotoInspectorSheet(item: item)
        }
        .onAppear {
            syncDeletedPhotos()
        }
        .onChange(of: cleanupManager.deletedAssetIds) {
            syncDeletedPhotos()
        }
    }
    
    private func syncDeletedPhotos() {
        guard !cleanupManager.deletedAssetIds.isEmpty else { return }
        withAnimation {
            blurryPhotos.removeAll { cleanupManager.deletedAssetIds.contains($0.id) }
        }
    }
}

// MARK: - Blurry Photo Inspector Sheet
struct BlurryPhotoInspectorSheet: View {
    let item: BlurryPhotoItem
    @ObservedObject private var cleanupManager = CleanupManager.shared
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationStack {
            ZStack {
                Color.black.ignoresSafeArea()
                
                VStack(spacing: 0) {
                    PHAssetThumbnailView(asset: item.photo.asset)
                        .aspectRatio(contentMode: .fit)
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    
                    VStack(spacing: 14) {
                        HStack(spacing: 12) {
                            HStack(spacing: 4) {
                                Image(systemName: "eye.slash.fill")
                                    .foregroundColor(AppTheme.accentOrange)
                                Text(item.formattedSharpness)
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(AppTheme.accentOrange)
                            }
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(AppTheme.accentOrange.opacity(0.18))
                            .clipShape(Capsule())
                            
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Low Optical Focus")
                                    .font(.system(size: 13, weight: .bold))
                                    .foregroundColor(.white)
                                Text("\(item.photo.formattedSize) • \(item.photo.asset.pixelWidth) × \(item.photo.asset.pixelHeight)")
                                    .font(.caption2)
                                    .foregroundColor(.gray)
                            }
                            
                            Spacer()
                            
                            let isSelected = cleanupManager.selectedPhotoIds.contains(item.id)
                            Button {
                                HapticManager.shared.impact(.light)
                                withAnimation {
                                    cleanupManager.togglePhoto(item.photo)
                                }
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    Text(isSelected ? "Marked for Delete" : "Keep Photo")
                                }
                                .font(.system(size: 13, weight: .bold))
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
            .navigationTitle("Blurry Inspection")
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
