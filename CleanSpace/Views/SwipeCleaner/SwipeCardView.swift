import SwiftUI
import Photos

struct SwipeCardView: View {
    let photo: PhotoItem
    var onSwiped: (SwipeDecision) -> Void
    
    @State private var offset: CGSize = .zero
    
    private var swipeProgress: Double {
        Double(offset.width / 150.0)
    }
    
    var body: some View {
        GeometryReader { geometry in
            ZStack(alignment: .bottom) {
                // Main Photo
                PHAssetThumbnailView(asset: photo.asset)
                    .frame(width: geometry.size.width, height: geometry.size.height)
                    .clipped()
                
                // Bottom Gradient Info Overlay
                LinearGradient(
                    colors: [Color.clear, Color.black.opacity(0.75)],
                    startPoint: .center,
                    endPoint: .bottom
                )
                .frame(height: 120)
                
                // Photo Details
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(photo.formattedSize)
                            .font(.headline)
                            .fontWeight(.bold)
                            .foregroundColor(.white)
                        
                        if let date = photo.creationDate {
                            Text(date.formatted(date: .abbreviated, time: .shortened))
                                .font(.caption)
                                .foregroundColor(Color.white.opacity(0.8))
                        }
                    }
                    
                    Spacer()
                    
                    Text("\(photo.pixelWidth) × \(photo.pixelHeight)")
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color.white.opacity(0.2))
                        .clipShape(Capsule())
                }
                .padding(20)
                
                // Top Stamps
                VStack {
                    HStack {
                        // KEEP Stamp (Visible on drag right)
                        if offset.width > 20 {
                            HStack(spacing: 6) {
                                Image(systemName: "checkmark.circle.fill")
                                Text("KEEP")
                            }
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundColor(AppTheme.accentEmerald)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(AppTheme.accentEmerald, lineWidth: 3)
                            )
                            .rotationEffect(.degrees(-15))
                            .opacity(min(1.0, Double(offset.width) / 80.0))
                            .padding(24)
                            
                            Spacer()
                        }
                        
                        // DELETE Stamp (Visible on drag left)
                        if offset.width < -20 {
                            Spacer()
                            
                            HStack(spacing: 6) {
                                Image(systemName: "trash.fill")
                                Text("DELETE")
                            }
                            .font(.system(size: 24, weight: .heavy, design: .rounded))
                            .foregroundColor(AppTheme.accentRed)
                            .padding(.horizontal, 16)
                            .padding(.vertical, 8)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(AppTheme.accentRed, lineWidth: 3)
                            )
                            .rotationEffect(.degrees(15))
                            .opacity(min(1.0, Double(-offset.width) / 80.0))
                            .padding(24)
                        }
                    }
                    
                    Spacer()
                }
            }
            .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
            .shadow(color: Color.black.opacity(0.2), radius: 12, x: 0, y: 6)
            .offset(x: offset.width, y: offset.height * 0.2)
            .rotationEffect(.degrees(Double(offset.width / 20)))
            .gesture(
                DragGesture()
                    .onChanged { gesture in
                        offset = gesture.translation
                    }
                    .onEnded { gesture in
                        let threshold: CGFloat = 100
                        if gesture.translation.width > threshold {
                            // Swiped Right -> Keep
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                offset.width = 600
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                onSwiped(.keep)
                            }
                        } else if gesture.translation.width < -threshold {
                            // Swiped Left -> Delete
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                offset.width = -600
                            }
                            DispatchQueue.main.asyncAfter(deadline: .now() + 0.15) {
                                onSwiped(.delete)
                            }
                        } else {
                            // Snap back
                            withAnimation(.spring(response: 0.35, dampingFraction: 0.7)) {
                                offset = .zero
                            }
                        }
                    }
            )
        }
    }
}
