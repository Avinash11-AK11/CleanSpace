//
//  AboutAppView.swift
//  CleanSpace
//
//  Created by Avinash Chavda on 24/09/2026, 10:11 AM.
//  Copyright © 2026 Avinash Chavda. All rights reserved.
//

import SwiftUI

struct AboutAppView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    
    private let githubURL = URL(string: "https://github.com/Avinash11-AK11")!
    private let repoURL = URL(string: "https://github.com/Avinash11-AK11/CleanSpace")!
    private let emailURL = URL(string: "mailto:chavdaavinash24@gmail.com")!
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    appHeaderSection
                    
                    creatorCard
                    
                    linksSection
                    
                    featuresSection
                    
                    privacyGuaranteeCard
                    
                    footerSection
                }
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 32)
            }
            .background(AppTheme.primaryBackground)
            .navigationTitle("About CleanSpace")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .font(.body.weight(.semibold))
                    .foregroundColor(AppTheme.accentEmerald)
                }
            }
        }
    }
    
    // MARK: - Subviews
    
    private var appHeaderSection: some View {
        VStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 24, style: .continuous)
                    .fill(AppTheme.emeraldGradient)
                    .frame(width: 88, height: 88)
                    .shadow(color: AppTheme.accentEmerald.opacity(0.35), radius: 16, x: 0, y: 8)
                
                Image(systemName: "sparkles")
                    .font(.system(size: 42, weight: .bold))
                    .foregroundColor(.white)
            }
            .padding(.top, 8)
            
            VStack(spacing: 4) {
                Text("CleanSpace")
                    .font(.system(size: 26, weight: .heavy, design: .rounded))
                    .foregroundColor(.primary)
                
                Text("Version 1.0.0 (Build 1)")
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.subtleGray)
            }
            
            Text("A native, privacy-first iOS utility built to reclaim storage safely with intelligent on-device clustering and compression.")
                .font(.subheadline)
                .foregroundColor(AppTheme.subtleGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 12)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }
    
    private var creatorCard: some View {
        VStack(spacing: 14) {
            HStack(spacing: 16) {
                ZStack {
                    Circle()
                        .fill(AppTheme.accentBlue.opacity(0.18))
                        .frame(width: 54, height: 54)
                    
                    Text("AC")
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundColor(AppTheme.accentBlue)
                }
                
                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text("Avinash Chavda")
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                        
                        Image(systemName: "checkmark.seal.fill")
                            .font(.caption)
                            .foregroundColor(AppTheme.accentEmerald)
                    }
                    
                    Text("Creator & Lead iOS Developer")
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(AppTheme.subtleGray)
                    
                    Text("Architected & Built CleanSpace")
                        .font(.caption2)
                        .foregroundColor(AppTheme.accentEmerald)
                }
                
                Spacer()
            }
            
            Divider().opacity(0.5)
            
            HStack(spacing: 10) {
                Button {
                    HapticManager.shared.impact(.light)
                    openURL(githubURL)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "link")
                            .font(.caption.bold())
                        Text("GitHub Profile")
                            .font(.caption.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppTheme.cardBorder.opacity(0.5))
                    .foregroundColor(.primary)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(BounceButtonStyle())
                
                Button {
                    HapticManager.shared.impact(.light)
                    openURL(repoURL)
                } label: {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.up.forward.app")
                            .font(.caption.bold())
                        Text("Repository")
                            .font(.caption.bold())
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .background(AppTheme.accentEmerald.opacity(0.15))
                    .foregroundColor(AppTheme.accentEmerald)
                    .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                }
                .buttonStyle(BounceButtonStyle())
            }
        }
        .padding(18)
        .cleanCardStyle(cornerRadius: 18)
    }
    
    private var linksSection: some View {
        VStack(spacing: 0) {
            linkRow(
                icon: "envelope.fill",
                iconColor: AppTheme.accentPurple,
                title: "Contact Developer",
                subtitle: "chavdaavinash24@gmail.com"
            ) {
                openURL(emailURL)
            }
            
            Divider().padding(.leading, 56)
            
            linkRow(
                icon: "chevron.left.forwardslash.chevron.right",
                iconColor: AppTheme.accentOrange,
                title: "Source Code on GitHub",
                subtitle: "Avinash11-AK11/CleanSpace"
            ) {
                openURL(repoURL)
            }
        }
        .cleanCardStyle(cornerRadius: 16)
    }
    
    private func linkRow(icon: String, iconColor: Color, title: String, subtitle: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(iconColor.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundColor(iconColor)
                }
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    Text(subtitle)
                        .font(.caption)
                        .foregroundColor(AppTheme.subtleGray)
                }
                
                Spacer()
                
                Image(systemName: "arrow.up.right")
                    .font(.caption.bold())
                    .foregroundColor(AppTheme.subtleGray)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private var featuresSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("KEY ARCHITECTURE & FEATURES")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.subtleGray)
                .tracking(1.0)
            
            VStack(spacing: 10) {
                featureItem(icon: "photo.stack", title: "Smart Photo Similarity", detail: "Multi-pass clustering & 768-dim perceptual downsampling.")
                featureItem(icon: "aqi.medium", title: "Blurry Photo Detection", detail: "Laplacian edge gradient variance + Vision face crop focus.")
                featureItem(icon: "film.stack", title: "Large Video Compression", detail: "AVFoundation export presets with dynamic bitrate sizing.")
                featureItem(icon: "hand.draw", title: "Swipe Photo Cleaner", detail: "Interactive Tinder-style review gesture cards.")
                featureItem(icon: "lock.shield", title: "Encrypted Photo Vault", detail: "Biometric Face ID authentication + Keychain passcode.")
                featureItem(icon: "person.2.circle", title: "Duplicate Contacts", detail: "Normalized phone & email address book deduplication.")
                featureItem(icon: "calendar.badge.clock", title: "Calendar Cleanup", detail: "Cleans expired events and clutter via EventKit.")
            }
        }
    }
    
    private func featureItem(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .bold))
                .foregroundColor(AppTheme.accentEmerald)
                .frame(width: 24, height: 24)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text(detail)
                    .font(.caption)
                    .foregroundColor(AppTheme.subtleGray)
            }
            
            Spacer()
        }
        .padding(14)
        .cleanCardStyle(cornerRadius: 14)
    }
    
    private var privacyGuaranteeCard: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(AppTheme.accentEmerald.opacity(0.15))
                    .frame(width: 44, height: 44)
                Image(systemName: "checkmark.shield.fill")
                    .font(.system(size: 22))
                    .foregroundColor(AppTheme.accentEmerald)
            }
            
            VStack(alignment: .leading, spacing: 3) {
                Text("100% On-Device Privacy")
                    .font(.subheadline)
                    .fontWeight(.bold)
                    .foregroundColor(.primary)
                Text("Photos, videos, and contacts never leave your device. Zero analytics, zero cloud dependencies.")
                    .font(.caption)
                    .foregroundColor(AppTheme.subtleGray)
            }
        }
        .padding(16)
        .cleanCardStyle(cornerRadius: 16)
    }
    
    private var footerSection: some View {
        VStack(spacing: 6) {
            Text("CleanSpace is open source under the MIT License.")
                .font(.caption2)
                .foregroundColor(AppTheme.subtleGray)
            
            Text("Copyright © 2026 Avinash Chavda. All rights reserved.")
                .font(.caption2)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.subtleGray.opacity(0.8))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 8)
    }
}
