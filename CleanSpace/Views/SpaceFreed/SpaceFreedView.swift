import SwiftUI

struct SpaceFreedView: View {
    @ObservedObject private var cleanupManager = CleanupManager.shared
    @Environment(\.dismiss) private var dismiss
    var onDone: (() -> Void)? = nil
    
    @State private var animateParticles = false
    
    var body: some View {
        ZStack {
            AppTheme.primaryBackground.ignoresSafeArea()
            
            // Confetti Particle Layer
            if animateParticles {
                ConfettiEffectView()
                    .ignoresSafeArea()
            }
            
            VStack(spacing: 24) {
                Spacer()
                
                // Celebration Icon
                ZStack {
                    Circle()
                        .fill(AppTheme.accentEmerald.opacity(0.18))
                        .frame(width: 120, height: 120)
                        .scaleEffect(animateParticles ? 1.05 : 0.95)
                        .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animateParticles)
                    
                    Image(systemName: "checkmark.circle.fill")
                        .font(.system(size: 72))
                        .foregroundColor(AppTheme.accentEmerald)
                }
                
                VStack(spacing: 8) {
                    Text("Clean Complete! 🎉")
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .foregroundColor(.primary)
                    
                    Text("You've successfully freed up valuable space")
                        .font(.subheadline)
                        .foregroundColor(AppTheme.subtleGray)
                }
                
                // Main Space Freed Metric Card
                VStack(spacing: 14) {
                    Text("SPACE RECOVERED")
                        .font(.caption2)
                        .fontWeight(.bold)
                        .foregroundColor(AppTheme.subtleGray)
                        .tracking(1.2)
                    
                    Text(ByteCountFormatter.string(fromByteCount: cleanupManager.lastFreedBytes, countStyle: .file))
                        .font(.system(size: 48, weight: .heavy, design: .rounded))
                        .foregroundColor(AppTheme.accentEmerald)
                    
                    HStack(spacing: 8) {
                        Image(systemName: "trash.circle.fill")
                            .foregroundColor(AppTheme.accentEmerald)
                        Text("\(cleanupManager.lastFreedItemCount) items safely removed")
                            .font(.subheadline.bold())
                            .foregroundColor(.primary)
                    }
                    
                    Divider()
                        .background(Color.gray.opacity(0.3))
                        .padding(.vertical, 4)
                    
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Lifetime Space Saved")
                                .font(.caption2)
                                .foregroundColor(AppTheme.subtleGray)
                            Text(ByteCountFormatter.string(fromByteCount: UserDefaults.standard.integer(forKey: "lifetime_freed_bytes") > 0 ? Int64(UserDefaults.standard.integer(forKey: "lifetime_freed_bytes")) : cleanupManager.lastFreedBytes, countStyle: .file))
                                .font(.subheadline.bold())
                                .foregroundColor(AppTheme.accentBlue)
                        }
                        
                        Spacer()
                        
                        // Share link
                        ShareLink(
                            item: "I just freed up \(ByteCountFormatter.string(fromByteCount: cleanupManager.lastFreedBytes, countStyle: .file)) on my iPhone using CleanSpace!",
                            subject: Text("CleanSpace Storage Cleaner"),
                            message: Text("CleanSpace helped declutter my photos, videos, and contacts 100% on-device.")
                        ) {
                            HStack(spacing: 6) {
                                Image(systemName: "square.and.arrow.up")
                                Text("Share")
                            }
                            .font(.caption.bold())
                            .foregroundColor(AppTheme.accentBlue)
                            .padding(.horizontal, 14)
                            .padding(.vertical, 8)
                            .background(AppTheme.accentBlue.opacity(0.12))
                            .clipShape(Capsule())
                        }
                        .buttonStyle(BounceButtonStyle())
                    }
                }
                .frame(maxWidth: .infinity)
                .padding(24)
                .cleanCardStyle(cornerRadius: 22)
                .padding(.horizontal, 24)
                
                // Device Health Note
                HStack(spacing: 8) {
                    Image(systemName: "sparkles")
                        .foregroundColor(AppTheme.accentEmerald)
                    Text("Zero cloud uploads. Your data stayed 100% private.")
                        .font(.caption)
                        .foregroundColor(AppTheme.subtleGray)
                }
                
                Spacer()
                
                Button("Done") {
                    HapticManager.shared.impact(.light)
                    dismiss()
                    onDone?()
                }
                .primaryButtonStyle(bg: AppTheme.accentEmerald)
                .buttonStyle(BounceButtonStyle())
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
        }
        .navigationBarBackButtonHidden(true)
        .onAppear {
            HapticManager.shared.notification(.success)
            animateParticles = true
            let prev = UserDefaults.standard.integer(forKey: "lifetime_freed_bytes")
            UserDefaults.standard.set(prev + Int(cleanupManager.lastFreedBytes), forKey: "lifetime_freed_bytes")
        }
    }
}

// Lightweight SwiftUI Confetti
private struct ConfettiEffectView: View {
    @State private var time: Double = 0.0
    private let colors: [Color] = [.green, .blue, .purple, .yellow, .pink, .orange]
    
    var body: some View {
        TimelineView(.animation) { timeline in
            Canvas { context, size in
                for i in 0..<40 {
                    let seed = Double(i)
                    let xPos = (sin(seed * 77.0) * 0.5 + 0.5) * size.width
                    let speed = (seed.truncatingRemainder(dividingBy: 5) + 3) * 60
                    let yOffset = fmod(timeline.date.timeIntervalSinceReferenceDate * speed + seed * 45, size.height + 40) - 20
                    let rect = CGRect(x: xPos, y: yOffset, width: 8, height: 12)
                    let color = colors[i % colors.count]
                    
                    context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(color.opacity(0.85)))
                }
            }
        }
    }
}
