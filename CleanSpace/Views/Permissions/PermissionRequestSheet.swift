//
//  PermissionRequestSheet.swift
//  CleanSpace
//
//  Created by Avinash Chavda on 22/09/2026, 06:03 PM.
//  Copyright © 2026 Avinash Chavda. All rights reserved.
//

import SwiftUI

struct PermissionRequestSheet: View {
    @ObservedObject var permissionManager = PermissionManager.shared
    @Environment(\.dismiss) private var dismiss
    var onDismiss: (() -> Void)? = nil
    
    var body: some View {
        VStack(spacing: 28) {
            Spacer()
            
            // Icon
            ZStack {
                Circle()
                    .fill(AppTheme.accentEmerald.opacity(0.12))
                    .frame(width: 90, height: 90)
                
                Image(systemName: "sparkles.rectangle.stack")
                    .font(.system(size: 40))
                    .foregroundColor(AppTheme.accentEmerald)
            }
            
            VStack(spacing: 8) {
                Text("Welcome to CleanSpace")
                    .font(.title2)
                    .fontWeight(.bold)
                
                Text("To detect duplicates, screenshots, large videos, and duplicate contacts, CleanSpace needs access to your library.")
                    .font(.subheadline)
                    .foregroundColor(AppTheme.subtleGray)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }
            
            VStack(spacing: 16) {
                // Photos Row
                HStack(spacing: 16) {
                    Image(systemName: "photo.stack.fill")
                        .font(.title2)
                        .foregroundColor(AppTheme.accentBlue)
                        .frame(width: 44)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Photo Library")
                            .font(.headline)
                        Text("Scans duplicates, screenshots & videos")
                            .font(.caption)
                            .foregroundColor(AppTheme.subtleGray)
                    }
                    
                    Spacer()
                    
                    if permissionManager.hasPhotoAccess {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(AppTheme.accentEmerald)
                    } else {
                        Button("Allow") {
                            Task {
                                _ = await permissionManager.requestPhotoAccess()
                            }
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(AppTheme.accentBlue)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                    }
                }
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                
                // Contacts Row
                HStack(spacing: 16) {
                    Image(systemName: "person.2.fill")
                        .font(.title2)
                        .foregroundColor(AppTheme.accentPurple)
                        .frame(width: 44)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Contacts")
                            .font(.headline)
                        Text("Finds duplicate & redundant address cards")
                            .font(.caption)
                            .foregroundColor(AppTheme.subtleGray)
                    }
                    
                    Spacer()
                    
                    if permissionManager.hasContactAccess {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(AppTheme.accentEmerald)
                    } else {
                        Button("Allow") {
                            Task {
                                _ = await permissionManager.requestContactAccess()
                            }
                        }
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 6)
                        .background(AppTheme.accentPurple)
                        .foregroundColor(.white)
                        .clipShape(Capsule())
                    }
                }
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .padding(.horizontal)
            
            // Privacy Assurance Note
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .foregroundColor(AppTheme.accentEmerald)
                Text("100% On-Device. No photos or contacts ever leave your phone.")
                    .font(.caption2)
                    .foregroundColor(AppTheme.subtleGray)
            }
            
            Spacer()
            
            Button("Continue") {
                dismiss()
                onDismiss?()
            }
            .primaryButtonStyle(bg: AppTheme.accentEmerald)
            .padding(.horizontal, 20)
            .padding(.bottom, 16)
        }
        .background(AppTheme.primaryBackground)
    }
}
