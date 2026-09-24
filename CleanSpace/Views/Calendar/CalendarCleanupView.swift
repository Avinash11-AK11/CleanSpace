//
//  CalendarCleanupView.swift
//  CleanSpace
//
//  Created by Avinash Chavda on 23/09/2026, 10:55 AM.
//  Copyright © 2026 Avinash Chavda. All rights reserved.
//

import SwiftUI
import EventKit

struct CalendarCleanupView: View {
    @StateObject private var scanner = CalendarScanner.shared
    @State private var selectedPeriod: CalendarFilterPeriod = .oneMonth
    @State private var selectedEventIds: Set<String> = []
    @State private var showingConfirmDialog = false
    @State private var isDeleting = false
    @State private var showPermissionPrompt = false
    @State private var showSuccessToast = false
    @State private var deletedCount = 0
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter Pills Picker
            VStack(spacing: 12) {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(CalendarFilterPeriod.allCases) { period in
                            let isSelected = selectedPeriod == period
                            Button {
                                HapticManager.shared.selection()
                                withAnimation(.spring(response: 0.3)) {
                                    selectedPeriod = period
                                }
                            } label: {
                                Text(period.shortTitle)
                                    .font(.subheadline)
                                    .fontWeight(isSelected ? .bold : .medium)
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 8)
                                    .background(isSelected ? AppTheme.accentEmerald : Color(uiColor: .tertiarySystemFill))
                                    .foregroundColor(isSelected ? .white : .primary)
                                    .clipShape(Capsule())
                            }
                            .buttonStyle(BounceButtonStyle())
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 8)
                .onChange(of: selectedPeriod) {
                    Task {
                        await scanner.fetchPastEvents(period: selectedPeriod)
                        selectedEventIds.removeAll()
                    }
                }
                
                HStack {
                    Text("\(scanner.events.count) old events found")
                        .font(.caption)
                        .foregroundColor(AppTheme.subtleGray)
                    
                    Spacer()
                    
                    if !scanner.events.isEmpty {
                        Button(selectedEventIds.count == scanner.events.count ? "Deselect All" : "Select All") {
                            HapticManager.shared.selection()
                            if selectedEventIds.count == scanner.events.count {
                                selectedEventIds.removeAll()
                            } else {
                                selectedEventIds = Set(scanner.events.map { $0.id })
                            }
                        }
                        .font(.caption.bold())
                        .foregroundColor(AppTheme.accentEmerald)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 8)
            }
            .background(AppTheme.cardBackground)
            
            // Content List
            if scanner.isScanning {
                Spacer()
                ProgressView("Searching calendar...")
                    .tint(AppTheme.accentEmerald)
                Spacer()
            } else if scanner.authorizationStatus != .authorized && scanner.authorizationStatus != .fullAccess {
                Spacer()
                VStack(spacing: 16) {
                    Image(systemName: "calendar.badge.exclamationmark")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.accentOrange)
                    
                    Text("Calendar Access Needed")
                        .font(.headline)
                        .foregroundColor(.primary)
                    
                    Text("CleanSpace scans your past calendar events locally to help declutter expired entries and spam invites.")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.subtleGray)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                    
                    Button("Grant Calendar Access") {
                        Task {
                            let granted = await scanner.requestAccess()
                            if granted {
                                await scanner.fetchPastEvents(period: selectedPeriod)
                            }
                        }
                    }
                    .primaryButtonStyle(bg: AppTheme.accentEmerald)
                    .buttonStyle(BounceButtonStyle())
                    .padding(.horizontal, 40)
                }
                Spacer()
            } else if scanner.events.isEmpty {
                Spacer()
                VStack(spacing: 12) {
                    Image(systemName: "calendar.badge.checkmark")
                        .font(.system(size: 48))
                        .foregroundColor(AppTheme.accentEmerald)
                    Text("Calendar is clean!")
                        .font(.headline)
                        .foregroundColor(.primary)
                    Text("No old events matching '\(selectedPeriod.rawValue)' were found.")
                        .font(.caption)
                        .foregroundColor(AppTheme.subtleGray)
                }
                Spacer()
            } else {
                List {
                    ForEach(scanner.events) { event in
                        HStack(spacing: 14) {
                            Button {
                                HapticManager.shared.impact(.light)
                                if selectedEventIds.contains(event.id) {
                                    selectedEventIds.remove(event.id)
                                } else {
                                    selectedEventIds.insert(event.id)
                                }
                            } label: {
                                Image(systemName: selectedEventIds.contains(event.id) ? "checkmark.circle.fill" : "circle")
                                    .font(.system(size: 22))
                                    .foregroundColor(selectedEventIds.contains(event.id) ? AppTheme.accentEmerald : AppTheme.subtleGray)
                            }
                            .buttonStyle(PlainButtonStyle())
                            
                            VStack(alignment: .leading, spacing: 4) {
                                Text(event.title)
                                    .font(.subheadline.bold())
                                    .foregroundColor(.primary)
                                    .lineLimit(1)
                                
                                HStack(spacing: 6) {
                                    Text(event.formattedDate)
                                    Text("•")
                                    Text(event.calendarTitle)
                                }
                                .font(.caption2)
                                .foregroundColor(AppTheme.subtleGray)
                            }
                            
                            Spacer()
                        }
                        .padding(.vertical, 4)
                        .listRowBackground(AppTheme.cardBackground)
                    }
                }
                .listStyle(.plain)
            }
            
            // Bottom Action Bar (Floating Dock)
            if !selectedEventIds.isEmpty {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(selectedEventIds.count) Events Selected")
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                        Text("Ready to clean")
                            .font(.caption)
                            .foregroundColor(AppTheme.accentEmerald)
                    }
                    
                    Spacer()
                    
                    Button {
                        HapticManager.shared.impact(.medium)
                        showingConfirmDialog = true
                    } label: {
                        HStack(spacing: 6) {
                            if isDeleting {
                                ProgressView().tint(.white)
                            } else {
                                Image(systemName: "trash.fill")
                                Text("Delete Events")
                            }
                        }
                        .font(.subheadline.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .background(AppTheme.accentRed)
                        .clipShape(Capsule())
                    }
                    .buttonStyle(BounceButtonStyle())
                    .disabled(isDeleting)
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
        .navigationTitle("Calendar Cleanup")
        .navigationBarTitleDisplayMode(.inline)
        .confirmationDialog(
            "Delete \(selectedEventIds.count) past events?",
            isPresented: $showingConfirmDialog,
            titleVisibility: .visible
        ) {
            Button("Delete Permanently", role: .destructive) {
                deleteSelected()
            }
            Button("Cancel", role: .cancel) { }
        } message: {
            Text("These past events will be permanently removed from your calendar. This cannot be undone.")
        }
        .task {
            scanner.checkAuthorization()
            if scanner.authorizationStatus == .authorized || scanner.authorizationStatus == .fullAccess {
                await scanner.fetchPastEvents(period: selectedPeriod)
            }
        }
    }
    
    private func deleteSelected() {
        isDeleting = true
        Task {
            let count = await scanner.deleteEvents(withIds: selectedEventIds)
            deletedCount = count
            selectedEventIds.removeAll()
            isDeleting = false
            HapticManager.shared.notification(.success)
            showSuccessToast = true
        }
    }
}
