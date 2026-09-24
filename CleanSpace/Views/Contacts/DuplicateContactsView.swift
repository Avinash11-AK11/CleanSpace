//
//  DuplicateContactsView.swift
//  CleanSpace
//
//  Created by Avinash Chavda on 22/09/2026, 06:03 PM.
//  Copyright © 2026 Avinash Chavda. All rights reserved.
//

import SwiftUI
import Contacts

struct DuplicateContactsView: View {
    @Binding var groups: [ContactGroup]
    @ObservedObject private var cleanupManager = CleanupManager.shared
    @State private var isMerging = false
    @State private var mergeAlertMessage: String?
    @State private var showMergeAlert = false
    
    var body: some View {
        ZStack(alignment: .bottom) {
            ScrollView {
                VStack(spacing: 16) {
                    if groups.isEmpty {
                        VStack(spacing: 16) {
                            Spacer().frame(height: 60)
                            Image(systemName: "person.crop.circle.badge.checkmark")
                                .font(.system(size: 60))
                                .foregroundColor(AppTheme.accentEmerald)
                            Text("No Duplicate Contacts")
                                .font(.title3)
                                .fontWeight(.bold)
                            Text("Your contacts address book is clean and tidy!")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.subtleGray)
                        }
                        .padding()
                    } else {
                        HStack {
                            Text("\(groups.count) Groups of Duplicates")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(AppTheme.subtleGray)
                            Spacer()
                            Text("Merge duplicates or select to delete")
                                .font(.caption2)
                                .foregroundColor(AppTheme.subtleGray)
                        }
                        .padding(.horizontal)
                        
                        LazyVStack(spacing: 16) {
                            ForEach(groups) { group in
                                ContactGroupCard(group: group) {
                                    mergeGroup(group)
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer().frame(height: 100)
                }
                .padding(.top, 8)
            }
            
            // Floating review bar
            if cleanupManager.totalSelectedCount > 0 {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(cleanupManager.formattedTotalSelectedCount)
                            .font(.subheadline)
                            .fontWeight(.bold)
                        if cleanupManager.totalEstimatedBytes > 0 {
                            Text("Frees: \(cleanupManager.formattedEstimatedBytes)")
                                .font(.caption)
                                .foregroundColor(AppTheme.accentEmerald)
                        }
                    }
                    Spacer()
                    NavigationLink(destination: ReviewView()) {
                        HStack(spacing: 6) {
                            Text("Review Cleanup")
                            Image(systemName: "arrow.right")
                        }
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(AppTheme.accentEmerald)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(BounceButtonStyle())
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 14)
                .background(.ultraThinMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 24, style: .continuous)
                        .stroke(AppTheme.cardBorder, lineWidth: 1)
                )
                .shadow(color: Color.black.opacity(0.12), radius: 16, x: 0, y: 8)
                .padding(.horizontal, 16)
                .padding(.bottom, 12)
            }
        }
        .background(AppTheme.primaryBackground)
        .navigationTitle("Duplicate Contacts")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            syncDeletedContacts()
        }
        .onChange(of: cleanupManager.deletedContactIds) {
            syncDeletedContacts()
        }
        .alert("Contact Merge", isPresented: $showMergeAlert) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(mergeAlertMessage ?? "")
        }
    }
    
    private func syncDeletedContacts() {
        guard !cleanupManager.deletedContactIds.isEmpty else { return }
        withAnimation {
            var updatedGroups: [ContactGroup] = []
            for group in groups {
                let remaining = group.contacts.filter { !cleanupManager.deletedContactIds.contains($0.id) }
                if remaining.count >= 2 {
                    var updated = group
                    updated.contacts = remaining
                    if let keep = updated.recommendedKeepId, !remaining.contains(where: { $0.id == keep }) {
                        updated.recommendedKeepId = remaining.first?.id
                    }
                    updatedGroups.append(updated)
                }
            }
            groups = updatedGroups
        }
    }
    
    private func mergeGroup(_ group: ContactGroup) {
        HapticManager.shared.impact(.medium)
        Task {
            guard let primary = group.contacts.first(where: { $0.id == group.recommendedKeepId }) ?? group.contacts.first else { return }
            let duplicates = group.contacts.filter { $0.id != primary.id }
            guard !duplicates.isEmpty else { return }
            
            do {
                try await CleanupService.shared.mergeContacts(
                    primary: primary.contact,
                    duplicates: duplicates.map { $0.contact }
                )
                withAnimation {
                    // Remove group from view
                    groups.removeAll { $0.id == group.id }
                    // Clear from selection if selected
                    for d in duplicates {
                        cleanupManager.selectedContactIds.remove(d.id)
                    }
                }
                HapticManager.shared.notification(.success)
                mergeAlertMessage = "Successfully merged \(duplicates.count + 1) contacts into '\(primary.fullName)'."
                showMergeAlert = true
            } catch {
                HapticManager.shared.notification(.error)
                mergeAlertMessage = "Failed to merge contacts: \(error.localizedDescription)"
                showMergeAlert = true
            }
        }
    }
}

struct ContactGroupCard: View {
    let group: ContactGroup
    let onMerge: () -> Void
    @ObservedObject private var cleanupManager = CleanupManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header: Reason
            HStack {
                Image(systemName: "tag.fill")
                    .font(.caption2)
                    .foregroundColor(AppTheme.accentEmerald)
                Text(group.reason)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(AppTheme.accentEmerald)
                
                Spacer()
                
                HStack(spacing: 10) {
                    Button(action: onMerge) {
                        HStack(spacing: 4) {
                            Image(systemName: "arrow.triangle.merge")
                            Text("Merge")
                        }
                        .font(.caption2)
                        .fontWeight(.bold)
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(AppTheme.accentEmerald.opacity(0.15))
                        .foregroundColor(AppTheme.accentEmerald)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(BounceButtonStyle())
                    
                    Button("Select Duplicates") {
                        HapticManager.shared.selection()
                        withAnimation {
                            for contact in group.contacts where contact.id != group.recommendedKeepId {
                                cleanupManager.selectedContactIds.insert(contact.id)
                                cleanupManager.allContactsMap[contact.id] = contact
                            }
                        }
                    }
                    .buttonStyle(BounceButtonStyle())
                    .font(.caption2)
                    .fontWeight(.bold)
                    .foregroundColor(AppTheme.accentBlue)
                }
            }
            
            Divider()
                .background(AppTheme.cardBorder)
            
            // Contacts in this group
            VStack(spacing: 8) {
                ForEach(group.contacts) { item in
                    let isKeep = item.id == group.recommendedKeepId
                    let isSelected = cleanupManager.selectedContactIds.contains(item.id)
                    
                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color(uiColor: .systemFill))
                            .frame(width: 36, height: 36)
                            .overlay {
                                Text(item.fullName.prefix(1).uppercased())
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .foregroundColor(.primary)
                            }
                        
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(item.fullName)
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                
                                if isKeep {
                                    Text("Primary")
                                        .font(.system(size: 9, weight: .bold))
                                        .padding(.horizontal, 6)
                                        .padding(.vertical, 2)
                                        .background(AppTheme.accentBlue.opacity(0.15))
                                        .foregroundColor(AppTheme.accentBlue)
                                        .clipShape(Capsule())
                                }
                            }
                            
                            Text(item.primaryDetail)
                                .font(.caption)
                                .foregroundColor(AppTheme.subtleGray)
                        }
                        
                        Spacer()
                        
                        Button {
                            HapticManager.shared.selection()
                            withAnimation(.spring(response: 0.3)) {
                                cleanupManager.toggleContact(item)
                            }
                        } label: {
                            ZStack {
                                Circle()
                                    .fill(isSelected ? AppTheme.accentEmerald : Color(uiColor: .systemFill))
                                    .frame(width: 24, height: 24)
                                
                                Image(systemName: isSelected ? "checkmark" : "circle")
                                    .font(.system(size: 11, weight: .bold))
                                    .foregroundColor(isSelected ? .white : AppTheme.subtleGray)
                            }
                        }
                        .buttonStyle(PlainButtonStyle())
                    }
                    .padding(.vertical, 4)
                }
            }
        }
        .padding(16)
        .cleanCardStyle(cornerRadius: 18)
    }
}
