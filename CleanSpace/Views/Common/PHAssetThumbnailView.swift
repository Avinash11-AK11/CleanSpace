import SwiftUI
import Photos

struct PHAssetThumbnailView: View {
    let asset: PHAsset
    var targetSize: CGSize = CGSize(width: 200, height: 200)
    var contentMode: ContentMode = .fill
    
    @State private var image: UIImage?
    
    var body: some View {
        GeometryReader { proxy in
            ZStack {
                if let image = image {
                    Image(uiImage: image)
                        .resizable()
                        .aspectRatio(contentMode: contentMode)
                        .frame(width: proxy.size.width, height: proxy.size.height)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color(uiColor: .secondarySystemFill))
                        .overlay {
                            ProgressView()
                                .scaleEffect(0.8)
                        }
                }
            }
        }
        .task(id: asset.localIdentifier) {
            loadImage()
        }
    }
    
    private func loadImage() {
        let manager = PHImageManager.default()
        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = true
        options.deliveryMode = .fastFormat
        options.resizeMode = .none
        
        manager.requestImage(
            for: asset,
            targetSize: targetSize,
            contentMode: .aspectFill,
            options: options
        ) { fetchedImage, _ in
            if let fetchedImage = fetchedImage {
                self.image = fetchedImage
            } else {
                // Direct data fallback
                let dataOptions = PHImageRequestOptions()
                dataOptions.isNetworkAccessAllowed = true
                manager.requestImageDataAndOrientation(for: asset, options: dataOptions) { data, _, _, _ in
                    if let data = data, let img = UIImage(data: data) {
                        DispatchQueue.main.async {
                            self.image = img
                        }
                    }
                }
            }
        }
    }
}
