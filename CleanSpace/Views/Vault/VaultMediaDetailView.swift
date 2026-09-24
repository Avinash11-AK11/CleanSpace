//
//  VaultMediaDetailView.swift
//  CleanSpace
//
//  Created by Avinash Chavda on 23/09/2026, 10:55 AM.
//  Copyright © 2026 Avinash Chavda. All rights reserved.
//

import SwiftUI
import AVKit

struct VaultMediaDetailView: View {
    let item: VaultMediaItem
    @ObservedObject var vaultManager = VaultManager.shared
    @Environment(\.dismiss) private var dismiss
    
    @State private var showingDeleteAlert = false
    @State private var showingExportAlert = false
    @State private var exportSuccess = false
    @State private var loadedImage: UIImage? = nil
    
    var body: some View {
        ZStack {
            Color.black.ignoresSafeArea()
            
            VStack {
                Spacer()
                
                if item.isVideo {
                    let url = vaultManager.fileURL(for: item)
                    VideoPlayer(player: AVPlayer(url: url))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    if let image = loadedImage {
                        Image(uiImage: image)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ProgressView()
                            .tint(.white)
                    }
                }
                
                Spacer()
                
                // Bottom control bar
                HStack(spacing: 40) {
                    Button(role: .destructive) {
                        showingDeleteAlert = true
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "trash")
                                .font(.system(size: 20))
                            Text("Delete")
                                .font(.caption2)
                        }
                        .foregroundColor(.red)
                    }
                    
                    Spacer()
                    
                    Button {
                        Task {
                            do {
                                try await vaultManager.exportItemToPhotos(item)
                                exportSuccess = true
                                showingExportAlert = true
                            } catch {
                                print("Export failed: \(error)")
                            }
                        }
                    } label: {
                        VStack(spacing: 4) {
                            Image(systemName: "square.and.arrow.down")
                                .font(.system(size: 20))
                            Text("Export to Photos")
                                .font(.caption2)
                        }
                        .foregroundColor(AppTheme.accentBlue)
                    }
                }
                .padding(.horizontal, 40)
                .padding(.vertical, 16)
                .background(.ultraThinMaterial)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Text(item.dateAdded.formatted(date: .abbreviated, time: .shortened))
                    .font(.caption)
                    .foregroundColor(.white)
            }
        }
        .alert("Delete Item?", isPresented: $showingDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete Permanently", role: .destructive) {
                vaultManager.deleteItem(item)
                dismiss()
            }
        } message: {
            Text("This will permanently remove the item from your private vault.")
        }
        .alert("Exported", isPresented: $showingExportAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text("This media has been restored back to your iPhone Photos library.")
        }
        .task {
            if !item.isVideo {
                let url = vaultManager.fileURL(for: item)
                if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                    loadedImage = img
                }
            }
        }
    }
}
