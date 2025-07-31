import SwiftUI
import MapKit

struct MapSnapshotView: View {
    let location: LocationData
    @State private var snapshotImage: UIImage?
    @State private var isLoading = true
    
    var body: some View {
        ZStack {
            if let image = snapshotImage {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .clipped()
            } else if isLoading {
                ZStack {
                    Color(.systemGray6)
                    
                    VStack(spacing: 8) {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Loading map...")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                }
            } else {
                ZStack {
                    Color(.systemGray5)
                    
                    VStack(spacing: 8) {
                        Image(systemName: "map")
                            .font(.title2)
                            .foregroundStyle(Color.secondary)
                        Text("Map unavailable")
                            .font(.caption)
                            .foregroundStyle(Color.secondary)
                    }
                }
            }
        }
        .onAppear {
            generateSnapshot()
        }
    }
    
    private func generateSnapshot() {
        let coordinate = location.coordinate
        let region = MKCoordinateRegion(
            center: coordinate,
            latitudinalMeters: 1000,
            longitudinalMeters: 1000
        )
        
        let options = MKMapSnapshotter.Options()
        options.region = region
        options.size = CGSize(width: 300, height: 150)
        options.scale = UIScreen.main.scale
        
        let snapshotter = MKMapSnapshotter(options: options)
        
        snapshotter.start { snapshot, error in
            DispatchQueue.main.async {
                isLoading = false
                
                if let snapshot = snapshot {
                    // Add a pin to the snapshot
                    let image = snapshot.image
                    let pinPoint = snapshot.point(for: coordinate)
                    
                    UIGraphicsBeginImageContextWithOptions(image.size, true, image.scale)
                    image.draw(at: .zero)
                    
                    // Draw red pin
                    let pinImage = UIImage(systemName: "mappin.circle.fill")?
                        .withTintColor(.red, renderingMode: .alwaysOriginal)
                        .withConfiguration(UIImage.SymbolConfiguration(pointSize: 30))
                    
                    if let pinImage = pinImage {
                        let pinRect = CGRect(
                            x: pinPoint.x - pinImage.size.width / 2,
                            y: pinPoint.y - pinImage.size.height,
                            width: pinImage.size.width,
                            height: pinImage.size.height
                        )
                        pinImage.draw(in: pinRect)
                    }
                    
                    let finalImage = UIGraphicsGetImageFromCurrentImageContext()
                    UIGraphicsEndImageContext()
                    
                    snapshotImage = finalImage
                } else {
                    print("Snapshot error: \(error?.localizedDescription ?? "Unknown error")")
                }
            }
        }
    }
}
