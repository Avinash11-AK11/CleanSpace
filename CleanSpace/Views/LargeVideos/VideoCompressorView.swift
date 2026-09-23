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
        VideoCompressionService.shared.estimateCompressedSize(
            originalBytes: video.fileSize,
            duration: video.duration,
            preset: selectedPreset,
            videoWidth: video.pixelWidth,
            videoHeight: video.pixelHeight
        )
    }
    
    var estimatedSavings: Int64 {
        max(0, video.fileSize - estimatedSize)
    }
    
    var reclaimPercent: Int {
        guard video.fileSize > 0 else { return 0 }
        return min(99, max(5, Int(round((Double(estimatedSavings) / Double(video.fileSize)) * 100.0))))
    }
    
    var body: some View {
        VStack(spacing: 0) {
            sheetHeaderBar
            
            ScrollView {
                VStack(spacing: 20) {
                    videoOverviewCard
                    
                    if !isCompleted {
                        presetSelectionSection
                        savingsComparisonCard
                        deleteOriginalSection
                        compressionActionSection
                    } else {
                        successSection
                    }
                    
                    Spacer().frame(height: 30)
                }
                .padding(.top, 16)
            }
            .background(AppTheme.primaryBackground)
        }
        .background(AppTheme.primaryBackground)
        .onDisappear {
            if isCompleted {
                notifyCompletionOnce()
            }
        }
        .alert("Compression Failed", isPresented: $showError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An unexpected error occurred during compression.")
        }
    }
    
    private var sheetHeaderBar: some View {
        HStack {
            if !isCompressing {
                Button("Cancel") {
                    dismiss()
                }
                .font(.body)
                .fontWeight(.medium)
                .foregroundColor(AppTheme.accentEmerald)
            } else {
                Text("")
                    .frame(width: 50)
            }
            
            Spacer()
            
            Text("Compress Video")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
            
            Spacer()
            
            // Invisible balance item for exact centering
            Text("Cancel")
                .font(.body)
                .fontWeight(.medium)
                .opacity(0)
                .accessibilityHidden(true)
        }
        .padding(.horizontal, 20)
        .padding(.top, 14)
        .padding(.bottom, 12)
        .background(AppTheme.cardBackground)
        .overlay(
            Rectangle()
                .fill(AppTheme.cardBorder.opacity(0.5))
                .frame(height: 1),
            alignment: .bottom
        )
    }
    
    private var videoOverviewCard: some View {
        HStack(spacing: 16) {
            PHAssetThumbnailView(asset: video.asset)
                .frame(width: 76, height: 76)
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
                    
                    if video.pixelWidth > 0 && video.pixelHeight > 0 {
                        Text("\(video.pixelWidth)×\(video.pixelHeight)")
                            .font(.caption2)
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.subtleGray)
                    }
                    
                    Text("•")
                        .font(.caption2)
                        .foregroundColor(AppTheme.subtleGray.opacity(0.6))
                    
                    Text(video.formattedDuration)
                        .font(.caption)
                        .foregroundColor(AppTheme.subtleGray)
                }
            }
            
            Spacer()
        }
        .padding(16)
        .cleanCardStyle(cornerRadius: 18)
        .padding(.horizontal)
    }
    
    private var presetSelectionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("SELECT COMPRESSION LEVEL")
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(AppTheme.subtleGray)
                .tracking(1.0)
            
            VStack(spacing: 10) {
                ForEach(CompressionPreset.allCases) { preset in
                    let isSelected = selectedPreset == preset
                    let estSize = VideoCompressionService.shared.estimateCompressedSize(
                        originalBytes: video.fileSize,
                        duration: video.duration,
                        preset: preset,
                        videoWidth: video.pixelWidth,
                        videoHeight: video.pixelHeight
                    )
                    let saved = max(0, video.fileSize - estSize)
                    let pct = min(99, max(5, Int(round((Double(saved) / Double(max(1, video.fileSize))) * 100.0))))
                    
                    Button {
                        HapticManager.shared.selection()
                        withAnimation(.spring(response: 0.3, dampingFraction: 0.75)) {
                            selectedPreset = preset
                        }
                    } label: {
                        HStack(spacing: 12) {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 6) {
                                    Text(preset.title(for: video))
                                        .font(.subheadline)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.primary)
                                    
                                    if preset == .medium {
                                        Text("BEST")
                                            .font(.system(size: 9, weight: .bold))
                                            .padding(.horizontal, 5)
                                            .padding(.vertical, 1.5)
                                            .background(AppTheme.accentEmerald.opacity(0.18))
                                            .foregroundColor(AppTheme.accentEmerald)
                                            .clipShape(Capsule())
                                    }
                                }
                                
                                Text(preset.subtitle(for: video))
                                    .font(.caption2)
                                    .foregroundColor(AppTheme.subtleGray)
                                    .multilineTextAlignment(.leading)
                                
                                Text("Est. ~\(ByteCountFormatter.string(fromByteCount: estSize, countStyle: .file)) • Save ~\(pct)%")
                                    .font(.caption)
                                    .fontWeight(.medium)
                                    .foregroundColor(isSelected ? AppTheme.accentEmerald : AppTheme.subtleGray)
                            }
                            
                            Spacer()
                            
                            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                .font(.title3)
                                .foregroundColor(isSelected ? AppTheme.accentEmerald : AppTheme.subtleGray)
                        }
                        .padding(14)
                        .background(isSelected ? AppTheme.accentEmerald.opacity(0.10) : AppTheme.cardBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14, style: .continuous)
                                .stroke(isSelected ? AppTheme.accentEmerald : AppTheme.cardBorder, lineWidth: isSelected ? 1.5 : 1)
                        )
                    }
                    .buttonStyle(BounceButtonStyle())
                }
            }
        }
        .padding(.horizontal)
    }
    
    private var savingsComparisonCard: some View {
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
            
            Text("Reclaim ~\(ByteCountFormatter.string(fromByteCount: estimatedSavings, countStyle: .file)) (\(reclaimPercent)% smaller)")
                .font(.subheadline)
                .fontWeight(.bold)
                .foregroundColor(AppTheme.accentEmerald)
        }
        .frame(maxWidth: .infinity)
        .padding(18)
        .cleanCardStyle(cornerRadius: 18)
        .padding(.horizontal)
    }
    
    private var deleteOriginalSection: some View {
        Toggle(isOn: $deleteOriginal) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Delete Original Video")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                    .foregroundColor(.primary)
                Text(deleteOriginal ? "Saves space by moving original to Recently Deleted" : "Keeps both original and newly compressed copy")
                    .font(.caption)
                    .foregroundColor(AppTheme.subtleGray)
            }
        }
        .tint(AppTheme.accentEmerald)
        .padding(14)
        .cleanCardStyle(cornerRadius: 14)
        .padding(.horizontal)
    }
    
    private var compressionActionSection: some View {
        Group {
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
                .cleanCardStyle(cornerRadius: 16)
                .padding(.horizontal)
            } else {
                Button(action: startCompression) {
                    HStack(spacing: 8) {
                        Image(systemName: "arrow.down.right.and.arrow.up.left")
                            .font(.headline)
                        Text("Compress & Free Storage")
                            .font(.headline)
                    }
                }
                .primaryButtonStyle(bg: AppTheme.accentEmerald)
                .buttonStyle(BounceButtonStyle())
                .padding(.horizontal)
            }
        }
    }
    
    private var successSection: some View {
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
                let actualSavedPct = min(99, max(1, Int(round((Double(saved) / Double(max(1, video.fileSize))) * 100.0))))
                
                VStack(spacing: 12) {
                    HStack(spacing: 20) {
                        VStack(spacing: 2) {
                            Text("Original")
                                .font(.caption2)
                                .foregroundColor(AppTheme.subtleGray)
                            Text(video.formattedSize)
                                .font(.subheadline)
                                .fontWeight(.semibold)
                                .foregroundColor(AppTheme.subtleGray)
                        }
                        
                        Image(systemName: "arrow.right")
                            .font(.caption)
                            .foregroundColor(AppTheme.subtleGray.opacity(0.7))
                            
                        VStack(spacing: 2) {
                            Text("Compressed")
                                .font(.caption2)
                                .foregroundColor(AppTheme.subtleGray)
                            Text(ByteCountFormatter.string(fromByteCount: actualCompressedSize, countStyle: .file))
                                .font(.subheadline)
                                .fontWeight(.bold)
                                .foregroundColor(.primary)
                        }
                    }
                    
                    Divider().opacity(0.4)
                    
                    VStack(spacing: 4) {
                        Text(originalWasDeleted ? "Storage Reclaimed" : "Compressed File Size")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(AppTheme.subtleGray)
                        Text(ByteCountFormatter.string(fromByteCount: originalWasDeleted ? saved : actualCompressedSize, countStyle: .file))
                            .font(.system(size: 32, weight: .heavy, design: .rounded))
                            .foregroundColor(AppTheme.accentEmerald)
                        
                        if originalWasDeleted {
                            Text("(\(actualSavedPct)% smaller)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundColor(AppTheme.accentEmerald)
                        }
                    }
                }
                .padding(16)
                .frame(maxWidth: .infinity)
                .cleanCardStyle(cornerRadius: 16)
            }
            
            Button("Done") {
                HapticManager.shared.impact(.light)
                notifyCompletionOnce()
                dismiss()
            }
            .primaryButtonStyle(bg: AppTheme.accentEmerald)
            .buttonStyle(BounceButtonStyle())
            .padding(.top, 12)
        }
        .padding(.horizontal)
    }
    
    private func notifyCompletionOnce() {
        guard !hasNotifiedCompletion else { return }
        hasNotifiedCompletion = true
        onCompletion?(createdAssetId, originalWasDeleted)
    }
    
    private func startCompression() {
        HapticManager.shared.impact(.medium)
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
                
                HapticManager.shared.notification(.success)
                isCompressing = false
                isCompleted = true
            } catch {
                HapticManager.shared.notification(.error)
                isCompressing = false
                errorMessage = error.localizedDescription
                showError = true
            }
        }
    }
}
