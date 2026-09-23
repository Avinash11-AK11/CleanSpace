import SwiftUI
import Photos

struct VideoCompressorView: View {
    let video: VideoItem
    var onCompletion: ((_ newAssetId: String?, _ originalDeleted: Bool) -> Void)? = nil
    
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPreset: CompressionPreset = .medium
    @State private var deleteOriginal: Bool = true
    
    @State private var isCompressing = false
    @State private var progress: Double = 0.0
    @State private var statusText: String = ""
    @State private var isCompleted = false
    @State private var actualCompressedSize: Int64 = 0
    @State private var errorMessage: String?
    @State private var showError = false
    @State private var originalWasDeleted = false
    @State private var createdAssetId: String? = nil
    @State private var hasNotifiedCompletion = false
    
    var estimatedSize: Int64 {
        VideoCompressionService.shared.estimateCompressedSize(originalBytes: video.fileSize, preset: selectedPreset)
    }
    
    var estimatedSavings: Int64 {
        max(0, video.fileSize - estimatedSize)
    }
    
    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Video Overview Card
                    HStack(spacing: 16) {
                        PHAssetThumbnailView(asset: video.asset)
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Selected Video")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(AppTheme.subtleGray)
                            
                            Text(video.formattedSize)
                                .font(.title3)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            HStack(spacing: 8) {
                                Text(video.qualityLabel)
                                    .font(.caption2)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 6)
                                    .padding(.vertical, 2)
                                    .background(AppTheme.accentOrange.opacity(0.15))
                                    .foregroundColor(AppTheme.accentOrange)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                
                                Text(video.formattedDuration)
                                    .font(.caption)
                                    .foregroundColor(AppTheme.subtleGray)
                            }
                        }
                        
                        Spacer()
                    }
                    .padding(16)
                    .background(AppTheme.cardBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
                    .padding(.horizontal)
                    
                    if !isCompleted {
                        // Quality Preset Selection
                        VStack(alignment: .leading, spacing: 12) {
                            Text("SELECT COMPRESSION LEVEL")
                                .font(.caption)
                                .fontWeight(.semibold)
                                .foregroundColor(AppTheme.subtleGray)
                                .tracking(1.0)
                            
                            VStack(spacing: 10) {
                                ForEach(CompressionPreset.allCases) { preset in
                                    let isSelected = selectedPreset == preset
                                    Button {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            selectedPreset = preset
                                        }
                                    } label: {
                                        HStack {
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(preset.rawValue)
                                                    .font(.subheadline)
                                                    .fontWeight(.semibold)
                                                    .foregroundColor(.primary)
                                                
                                                Text("Est. ~\(ByteCountFormatter.string(fromByteCount: VideoCompressionService.shared.estimateCompressedSize(originalBytes: video.fileSize, preset: preset), countStyle: .file)) • Save ~\(Int(preset.reductionFactor * 100))%")
                                                    .font(.caption)
                                                    .foregroundColor(AppTheme.accentEmerald)
                                            }
                                            
                                            Spacer()
                                            
                                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                                .font(.title3)
                                                .foregroundColor(isSelected ? AppTheme.accentEmerald : AppTheme.subtleGray)
                                        }
                                        .padding(14)
                                        .background(isSelected ? AppTheme.accentEmerald.opacity(0.08) : AppTheme.cardBackground)
                                        .clipShape(RoundedRectangle(cornerRadius: 14))
                                        .overlay(
                                            RoundedRectangle(cornerRadius: 14)
                                                .stroke(isSelected ? AppTheme.accentEmerald : Color.clear, lineWidth: 1.5)
                                        )
                                    }
                                    .buttonStyle(PlainButtonStyle())
                                }
                            }
                        }
                        .padding(.horizontal)
                        
                        // Estimated Recovery Comparison Card
                        VStack(spacing: 14) {
                            Text("ESTIMATED SPACE SAVINGS")
                                .font(.caption2)
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.subtleGray)
                                .tracking(1.0)
                            
                            HStack(spacing: 24) {
                                VStack {
                                    Text(video.formattedSize)
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(AppTheme.subtleGray)
                                    Text("Before")
                                        .font(.caption2)
                                        .foregroundColor(AppTheme.subtleGray)
                                }
                                
                                Image(systemName: "arrow.right")
                                    .font(.title3)
                                    .foregroundColor(AppTheme.accentEmerald)
                                
                                VStack {
                                    Text(ByteCountFormatter.string(fromByteCount: estimatedSize, countStyle: .file))
                                        .font(.title3)
                                        .fontWeight(.bold)
                                        .foregroundColor(.primary)
                                    Text("After")
                                        .font(.caption2)
                                        .foregroundColor(AppTheme.subtleGray)
                                }
                            }
                            
                            Text("Reclaim ~\(ByteCountFormatter.string(fromByteCount: estimatedSavings, countStyle: .file)) (\(Int(selectedPreset.reductionFactor * 100))% smaller)")
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.accentEmerald)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(18)
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 18))
                        .padding(.horizontal)
                        
                        // Delete Original Toggle
                        Toggle(isOn: $deleteOriginal) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Delete Original Video")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .foregroundColor(.primary)
                                Text(deleteOriginal ? "Saves space by moving original to Recently Deleted" : "Keeps both original and newly compressed copy")
                                    .font(.caption)
                                    .foregroundColor(AppTheme.subtleGray)
                            }
                        }
                        .tint(AppTheme.accentEmerald)
                        .padding(14)
                        .background(AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .padding(.horizontal)
                        
                        // Compression Progress / Action Button
                        if isCompressing {
                            VStack(spacing: 12) {
                                ProgressView(value: progress)
                                    .tint(AppTheme.accentEmerald)
                                HStack {
                                    Text(statusText)
                                        .font(.caption)
                                        .foregroundColor(AppTheme.subtleGray)
                                    Spacer()
                                    Text("\(Int(progress * 100))%")
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
                            Button(action: startCompression) {
                                HStack {
                                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                                    Text("Compress & Free Storage")
                                }
                            }
                            .primaryButtonStyle(bg: AppTheme.accentEmerald)
                            .padding(.horizontal)
                        }
                    } else {
                        // Success View
                        VStack(spacing: 16) {
                            ZStack {
                                Circle()
                                    .fill(AppTheme.accentEmerald.opacity(0.15))
                                    .frame(width: 80, height: 80)
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.system(size: 48))
                                    .foregroundColor(AppTheme.accentEmerald)
                            }
                            
                            Text("Compression Complete!")
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                            
                            Text(originalWasDeleted ? "Compressed video saved and original removed." : "Compressed copy saved! Both original and compressed videos are in your library.")
                                .font(.subheadline)
                                .foregroundColor(AppTheme.subtleGray)
                                .multilineTextAlignment(.center)
                            
                            if actualCompressedSize > 0 {
                                let saved = max(0, video.fileSize - actualCompressedSize)
                                VStack(spacing: 4) {
                                    Text(originalWasDeleted ? "Space Saved" : "Compressed File Size")
                                        .font(.caption)
                                        .foregroundColor(AppTheme.subtleGray)
                                    Text(ByteCountFormatter.string(fromByteCount: originalWasDeleted ? saved : actualCompressedSize, countStyle: .file))
                                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                                        .foregroundColor(AppTheme.accentEmerald)
                                }
                                .padding()
                                .frame(maxWidth: .infinity)
                                .background(AppTheme.cardBackground)
                                .clipShape(RoundedRectangle(cornerRadius: 16))
                            }
                            
                            Button("Done") {
                                notifyCompletionOnce()
                                dismiss()
                            }
                            .primaryButtonStyle(bg: AppTheme.accentEmerald)
                            .padding(.top, 12)
                        }
                        .padding(.horizontal)
                    }
                    
                    Spacer().frame(height: 30)
                }
                .padding(.top, 8)
            }
            .background(AppTheme.primaryBackground)
            .navigationTitle("Compress Video")
            .navigationBarTitleDisplayMode(.inline)
            .onDisappear {
                if isCompleted {
                    notifyCompletionOnce()
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if !isCompressing {
                        Button("Cancel") {
                            dismiss()
                        }
                        .foregroundColor(AppTheme.accentEmerald)
                    }
                }
            }
            .alert("Compression Failed", isPresented: $showError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(errorMessage ?? "An unexpected error occurred during compression.")
            }
        }
    }
    
    private func notifyCompletionOnce() {
        guard !hasNotifiedCompletion else { return }
        hasNotifiedCompletion = true
        onCompletion?(createdAssetId, originalWasDeleted)
    }
    
    private func startCompression() {
        Task {
            isCompressing = true
            progress = 0.05
            statusText = "Preparing video export..."
            
            do {
                let tempURL = try await VideoCompressionService.shared.compressVideo(
                    asset: video.asset,
                    preset: selectedPreset
                ) { p in
                    Task { @MainActor in
                        self.progress = p
                        self.statusText = "Compressing video (\(Int(p * 100))%)..."
                    }
                }
                
                statusText = "Saving to Photos Library..."
                let attrs = try? FileManager.default.attributesOfItem(atPath: tempURL.path)
                let finalBytes = (attrs?[.size] as? Int64) ?? estimatedSize
                self.actualCompressedSize = finalBytes
                
                let result = try await VideoCompressionService.shared.saveCompressedVideo(
                    fileURL: tempURL,
                    originalAsset: video.asset,
                    deleteOriginal: deleteOriginal
                )
                
                self.createdAssetId = result.newAssetId
                self.originalWasDeleted = result.originalDeleted
                if result.originalDeleted {
                    CleanupManager.shared.deletedAssetIds.insert(video.id)
                }
                
                isCompressing = false
                isCompleted = true
            } catch {
                isCompressing = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
