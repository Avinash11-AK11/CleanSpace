import SwiftUI
import Contacts

struct DuplicateContactsView: View {
    let groups: [ContactGroup]
    @ObservedObject private var cleanupManager = CleanupManager.shared
    
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
                            Text("Keep the primary card, remove the rest")
                                .font(.caption2)
                                .foregroundColor(AppTheme.subtleGray)
                        }
                        .padding(.horizontal)
                        
                        LazyVStack(spacing: 16) {
                            ForEach(groups) { group in
                                ContactGroupCard(group: group)
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
                VStack(spacing: 0) {
                    Divider()
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("\(cleanupManager.totalSelectedCount) items selected")
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
        .navigationTitle("Duplicate Contacts")
        .navigationBarTitleDisplayMode(.inline)
    }
}

struct ContactGroupCard: View {
    let group: ContactGroup
    @ObservedObject private var cleanupManager = CleanupManager.shared
    
    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            // Header: Reason
            HStack {
                Image(systemName: "tag.fill")
                    .font(.caption2)
                    .foregroundColor(AppTheme.accentEmerald)
                Text(group.reason)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(AppTheme.accentEmerald)
                
                Spacer()
                
                Button("Select Duplicates") {
                    withAnimation {
                        for contact in group.contacts where contact.id != group.recommendedKeepId {
                            cleanupManager.selectedContactIds.insert(contact.id)
                            cleanupManager.allContactsMap[contact.id] = contact
                        }
                    }
                }
                .font(.caption2)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.accentBlue)
            }
            
            Divider()
            
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
        .padding(14)
        .background(AppTheme.cardBackground)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }
}
