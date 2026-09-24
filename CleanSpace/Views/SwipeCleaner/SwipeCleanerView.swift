//
//  SwipeCleanerView.swift
//  CleanSpace
//
//  Created by Avinash Chavda on 23/09/2026, 10:55 AM.
//  Copyright © 2026 Avinash Chavda. All rights reserved.
//

import SwiftUI
import Photos

struct SwipeCleanerView: View {
    @StateObject private var viewModel: SwipeCleanerViewModel
    @ObservedObject private var cleanupManager = CleanupManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var navigateToReview = false
    
    init(photos: [PhotoItem]) {
        _viewModel = StateObject(wrappedValue: SwipeCleanerViewModel(photos: photos))
    }
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 16) {
                if viewModel.photos.isEmpty {
                    VStack(spacing: 16) {
                        Spacer()
                        Image(systemName: "photo.on.rectangle.angled")
                            .font(.system(size: 64))
                            .foregroundColor(AppTheme.accentEmerald)
                        Text("No Photos to Swipe")
                            .font(.title3)
                            .fontWeight(.bold)
                        Text("Your library is currently empty.")
                            .font(.subheadline)
                            .foregroundColor(AppTheme.subtleGray)
                        Spacer()
                    }
                    .padding()
                } else if viewModel.isFinished {
                    // Completion Summary Screen
                    VStack(spacing: 24) {
                        Spacer()
                        
                        ZStack {
                            Circle()
                                .fill(AppTheme.accentEmerald.opacity(0.15))
                                .frame(width: 90, height: 90)
                            Image(systemName: "sparkles")
                                .font(.system(size: 48))
                                .foregroundColor(AppTheme.accentEmerald)
                        }
                        
                        VStack(spacing: 8) {
                            Text("Swipe Session Complete!")
                                .font(.system(size: 26, weight: .bold, design: .rounded))
                            Text("You reviewed \(viewModel.photos.count) photos")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.subtleGray)
                        }
                        
                        // Queued Stats Card
                        VStack(spacing: 12) {
                            Text("MARKED FOR DELETION")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.subtleGray)
                                .tracking(1.0)
                            
                            Text(viewModel.formattedCleanableBytes)
                                .font(.system(size: 40, weight: .heavy, design: .rounded))
                                .foregroundColor(AppTheme.accentEmerald)
                            
                            Text("\(viewModel.queuedForDeletion.count) photos queued")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.subtleGray)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(20)
                        .cleanCardStyle(cornerRadius: 20)
                        .padding(.horizontal)
                        
                        Spacer()
                        
                        VStack(spacing: 12) {
                            if !viewModel.queuedForDeletion.isEmpty {
                                Button("Review & Clean (\(viewModel.queuedForDeletion.count))") {
                                    HapticManager.shared.impact(.medium)
                                    // Queue into cleanup manager
                                    for item in viewModel.queuedForDeletion {
                                        cleanupManager.selectedPhotoIds.insert(item.id)
                                        cleanupManager.allPhotosMap[item.id] = item
                                    }
                                    navigateToReview = true
                                }
                                .primaryButtonStyle(bg: AppTheme.accentEmerald)
                                .buttonStyle(BounceButtonStyle())
                            }
                            
                            Button("Done") {
                                HapticManager.shared.impact(.light)
                                dismiss()
                            }
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(AppTheme.subtleGray)
                            .padding(.vertical, 8)
                        }
                        .padding(.horizontal, 20)
                        .padding(.bottom, 20)
                    }
                } else {
                    // Active Card Deck
                    // Top Progress Bar
                    VStack(spacing: 6) {
                        HStack {
                            Text("Photo \(viewModel.currentIndex + 1) of \(viewModel.photos.count)")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(AppTheme.subtleGray)
                            
                            Spacer()
                            
                            if !viewModel.queuedForDeletion.isEmpty {
                                HStack(spacing: 4) {
                                    Image(systemName: "trash.fill")
                                        .font(.caption2)
                                    Text("\(viewModel.queuedForDeletion.count) queued (\(viewModel.formattedCleanableBytes))")
                                        .font(.caption2)
                                        .fontWeight(.bold)
                                }
                                .foregroundColor(AppTheme.accentRed)
                                .padding(.horizontal, 8)
                                .padding(.vertical, 4)
                                .background(AppTheme.accentRed.opacity(0.12))
                                .clipShape(Capsule())
                            }
                        }
                        .padding(.horizontal, 20)
                        
                        ProgressView(value: Double(viewModel.currentIndex), total: Double(viewModel.photos.count))
                            .tint(AppTheme.accentEmerald)
                            .padding(.horizontal, 20)
                    }
                    
                    // Card Stack
                    ZStack {
                        // Background Card (Next photo preview)
                        if let next = viewModel.nextPhoto {
                            SwipeCardView(photo: next) { _ in }
                                .scaleEffect(0.94)
                                .offset(y: 14)
                                .opacity(0.7)
                                .allowsHitTesting(false)
                        }
                        
                        // Active Top Card
                        if let current = viewModel.currentPhoto {
                            SwipeCardView(photo: current) { decision in
                                viewModel.swipe(decision: decision)
                            }
                            .id(current.id)
                        }
                    }
                    .padding(.horizontal, 20)
                    .frame(maxHeight: .infinity)
                    
                    // Bottom Control Buttons
                    HStack(spacing: 28) {
                        // Undo Button
                        Button {
                            HapticManager.shared.selection()
                            withAnimation(.spring(response: 0.35)) {
                                viewModel.undo()
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(Color(uiColor: .secondarySystemFill))
                                    .frame(width: 52, height: 52)
                                Image(systemName: "arrow.uturn.backward")
                                    .font(.system(size: 18, weight: .bold))
                                    .foregroundColor(viewModel.history.isEmpty ? AppTheme.subtleGray.opacity(0.4) : .primary)
                            }
                            .shadow(color: Color.black.opacity(0.06), radius: 6, x: 0, y: 3)
                        }
                        .buttonStyle(BounceButtonStyle())
                        .disabled(viewModel.history.isEmpty)
                        
                        // Delete Button (Swipe Left)
                        Button {
                            HapticManager.shared.impact(.medium)
                            withAnimation(.spring(response: 0.35)) {
                                viewModel.swipe(decision: .delete)
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.accentRed.opacity(0.12))
                                    .frame(width: 68, height: 68)
                                    .overlay(
                                        Circle()
                                            .stroke(AppTheme.accentRed.opacity(0.3), lineWidth: 1.5)
                                    )
                                Image(systemName: "trash.fill")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundColor(AppTheme.accentRed)
                            }
                            .shadow(color: AppTheme.accentRed.opacity(0.15), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(BounceButtonStyle())
                        
                        // Keep Button (Swipe Right)
                        Button {
                            HapticManager.shared.impact(.light)
                            withAnimation(.spring(response: 0.35)) {
                                viewModel.swipe(decision: .keep)
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.accentEmerald.opacity(0.15))
                                    .frame(width: 68, height: 68)
                                    .overlay(
                                        Circle()
                                            .stroke(AppTheme.accentEmerald.opacity(0.3), lineWidth: 1.5)
                                    )
                                Image(systemName: "checkmark")
                                    .font(.system(size: 26, weight: .bold))
                                    .foregroundColor(AppTheme.accentEmerald)
                            }
                            .shadow(color: AppTheme.accentEmerald.opacity(0.15), radius: 8, x: 0, y: 4)
                        }
                        .buttonStyle(BounceButtonStyle())
                    }
                    .padding(.vertical, 8)
                    .padding(.bottom, 20)
                }
            }
            .background(AppTheme.primaryBackground)
            .navigationTitle("Swipe Cleaner")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
            }
            .navigationDestination(isPresented: $navigateToReview) {
                ReviewView {
                    dismiss()
                }
            }
        }
    }
}
