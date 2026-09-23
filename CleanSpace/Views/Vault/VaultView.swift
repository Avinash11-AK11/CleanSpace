import SwiftUI
import PhotosUI

struct VaultView: View {
    @ObservedObject var vaultManager = VaultManager.shared
    @State private var showingAuthSheet = false
    @State private var showingPhotoPicker = false
    @State private var selectedPickerItems: [PhotosPickerItem] = []
    @State private var isImporting = false
    
    private let columns = [
        GridItem(.adaptive(minimum: 100, maximum: 140), spacing: 8)
    ]
    
    var body: some View {
        Group {
            if !vaultManager.isUnlocked {
                lockedPlaceholderView
            } else {
                unlockedContentView
            }
        }
        .navigationTitle("Secret Vault")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if vaultManager.isUnlocked {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        vaultManager.lock()
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "lock.fill")
                            Text("Lock")
                        }
                        .font(.caption.bold())
                        .foregroundColor(AppTheme.accentPurple)
                    }
                }
            }
        }
        .sheet(isPresented: $showingAuthSheet) {
            VaultLockView()
        }
        .photosPicker(
            isPresented: $showingPhotoPicker,
            selection: $selectedPickerItems,
            matching: .any(of: [.images, .videos])
        )
        .onChange(of: selectedPickerItems) {
            guard !selectedPickerItems.isEmpty else { return }
            handlePickerItems(selectedPickerItems)
        }
        .onAppear {
            if !vaultManager.isUnlocked {
                showingAuthSheet = true
            }
        }
    }
    
    private var lockedPlaceholderView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            ZStack {
                Circle()
                    .fill(AppTheme.accentPurple.opacity(0.15))
                    .frame(width: 90, height: 90)
                
                Image(systemName: "lock.shield.fill")
                    .font(.system(size: 42))
                    .foregroundColor(AppTheme.accentPurple)
            }
            
            Text("Vault is Locked")
                .font(.title2.bold())
            
            Text("Your hidden items are encrypted and secured on your device with hardware protection.")
                .font(.subheadline)
                .foregroundColor(AppTheme.subtleGray)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Button {
                showingAuthSheet = true
            } label: {
                HStack {
                    Image(systemName: "key.fill")
                    Text("Unlock Vault")
                }
            }
            .primaryButtonStyle(bg: AppTheme.accentPurple)
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .background(AppTheme.primaryBackground)
    }
    
    private var unlockedContentView: some View {
        ScrollView {
            VStack(spacing: 16) {
                // Info banner
                HStack(spacing: 12) {
                    Image(systemName: "shield.lefthalf.filled")
                        .font(.title2)
                        .foregroundColor(AppTheme.accentPurple)
                    
                    VStack(alignment: .leading, spacing: 2) {
                        Text("\(vaultManager.items.count) Private Items (\(vaultManager.formattedVaultSize))")
                            .font(.subheadline.bold())
                        Text("Protected with PIN or Face ID")
                            .font(.caption)
                            .foregroundColor(AppTheme.subtleGray)
                    }
                    
                    Spacer()
                    
                    Button {
                        showingPhotoPicker = true
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "plus")
                            Text("Add")
                        }
                        .font(.caption.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 8)
                        .background(AppTheme.accentPurple)
                        .clipShape(Capsule())
                    }
                }
                .padding()
                .background(AppTheme.cardBackground)
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .padding(.horizontal)
                .padding(.top, 8)
                
                if isImporting {
                    HStack(spacing: 10) {
                        ProgressView()
                            .tint(AppTheme.accentPurple)
                        Text("Importing into vault...")
                            .font(.caption)
                            .foregroundColor(AppTheme.subtleGray)
                    }
                    .padding()
                }
                
                if vaultManager.items.isEmpty {
                    VStack(spacing: 12) {
                        Spacer().frame(height: 60)
                        Image(systemName: "photo.stack")
                            .font(.system(size: 48))
                            .foregroundColor(AppTheme.subtleGray.opacity(0.5))
                        Text("No items in your vault")
                            .font(.headline)
                            .foregroundColor(AppTheme.subtleGray)
                        Text("Tap + Add to import sensitive photos or videos into your private vault.")
                            .font(.caption)
                            .foregroundColor(AppTheme.subtleGray)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    LazyVGrid(columns: columns, spacing: 8) {
                        ForEach(vaultManager.items) { item in
                            NavigationLink(destination: VaultMediaDetailView(item: item)) {
                                VaultThumbnailCell(item: item)
                            }
                            .buttonStyle(PlainButtonStyle())
                        }
                    }
                    .padding(.horizontal)
                }
            }
        }
        .background(AppTheme.primaryBackground)
    }
    
    private func handlePickerItems(_ items: [PhotosPickerItem]) {
        isImporting = true
        Task {
            for item in items {
                // If asset identifier is available
                if let identifier = item.itemIdentifier {
                    let fetchResult = PHAsset.fetchAssets(withLocalIdentifiers: [identifier], options: nil)
                    if let asset = fetchResult.firstObject {
                        try? await vaultManager.importAsset(asset, deleteOriginal: false)
                        continue
                    }
                }
                
                // Fallback for photo data
                if let data = try? await item.loadTransferable(type: Data.self) {
                    let id = UUID()
                    let filename = "\(id.uuidString).jpg"
                    let targetURL = vaultManager.fileURL(for: VaultMediaItem(id: id, filename: filename, mediaType: "image", fileSize: Int64(data.count), dateAdded: Date(), originalCreationDate: nil))
                    try? data.write(to: targetURL, options: .atomic)
                    let vItem = VaultMediaItem(id: id, filename: filename, mediaType: "image", fileSize: Int64(data.count), dateAdded: Date(), originalCreationDate: nil)
                    vaultManager.items.insert(vItem, at: 0)
                }
            }
            selectedPickerItems = []
            isImporting = false
        }
    }
}

private struct VaultThumbnailCell: View {
    let item: VaultMediaItem
    @ObservedObject var vaultManager = VaultManager.shared
    @State private var thumbnail: UIImage? = nil
    
    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            if let img = thumbnail {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFill()
                    .frame(minWidth: 0, maxWidth: .infinity)
                    .aspectRatio(1.0, contentMode: .fit)
                    .clipped()
                    .cornerRadius(8)
            } else {
                Rectangle()
                    .fill(AppTheme.cardBackground)
                    .aspectRatio(1.0, contentMode: .fit)
                    .overlay(
                        ProgressView().tint(AppTheme.accentPurple)
                    )
                    .cornerRadius(8)
            }
            
            HStack(spacing: 3) {
                if item.isVideo {
                    Image(systemName: "video.fill")
                        .font(.system(size: 8))
                }
                Text(item.formattedSize)
                    .font(.system(size: 9, weight: .bold))
            }
            .foregroundColor(.white)
            .padding(.horizontal, 5)
            .padding(.vertical, 2)
            .background(Color.black.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .padding(4)
        }
        .task {
            let url = vaultManager.fileURL(for: item)
            if !item.isVideo {
                if let data = try? Data(contentsOf: url), let img = UIImage(data: data) {
                    thumbnail = img
                }
            } else {
                // Generate video thumbnail
                let asset = AVAsset(url: url)
                let generator = AVAssetImageGenerator(asset: asset)
                generator.appliesPreferredTrackTransform = true
                if let cgImage = try? generator.copyCGImage(at: .zero, actualTime: nil) {
                    thumbnail = UIImage(cgImage: cgImage)
                }
            }
        }
    }
}
