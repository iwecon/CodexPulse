import CoreGraphics
import Photos

/// User-facing photo library access states used by the permission control.
enum PhotoLibraryAccessState: Sendable, Equatable {
    /// Access has never been requested; the system prompt is still available.
    case notDetermined
    /// Full or limited read access is available.
    case granted
    /// The user declined earlier; only System Settings can change it now.
    case denied
}

/// Resolves a Photos-library wallpaper asset to pixels through PhotoKit.
///
/// The wallpaper Store only records the asset identifier for
/// `com.apple.wallpaper.extension.photos` selections; the picture itself is
/// TCC-protected inside the Photos library. Sampling NEVER triggers the
/// system permission prompt: it uses access only when it has already been
/// granted through the panel's permission control (`requestAccess()`), and
/// otherwise the caller keeps the system-appearance fallback. Only a small
/// thumbnail is requested and nothing is downloaded from the network.
final class PhotoLibraryWallpaperImageLoader: WallpaperPhotoImageLoading, Sendable {
    static let thumbnailTargetSize = CGSize(width: 384, height: 384)

    static var accessState: PhotoLibraryAccessState {
        switch PHPhotoLibrary.authorizationStatus(for: .readWrite) {
        case .authorized, .limited: .granted
        case .notDetermined: .notDetermined
        case .denied, .restricted: .denied
        @unknown default: .denied
        }
    }

    /// Shows the system authorization prompt. Only the permission control in
    /// the Usage Overview Panel calls this — never the sampling path.
    static func requestAccess() async -> Bool {
        let granted = await PHPhotoLibrary.requestAuthorization(for: .readWrite)
        return granted == .authorized || granted == .limited
    }

    func image(forAssetIdentifier identifier: String) async -> CGImage? {
        guard Self.accessState == .granted else { return nil }
        // The Store records the bare UUID while PhotoKit local identifiers
        // carry a suffix; fetch tolerates both forms.
        let assets = PHAsset.fetchAssets(
            withLocalIdentifiers: [identifier, "\(identifier)/L0/001"],
            options: nil
        )
        guard let asset = assets.firstObject else { return nil }

        let options = PHImageRequestOptions()
        options.isNetworkAccessAllowed = false
        options.deliveryMode = .highQualityFormat
        options.resizeMode = .fast
        return await withCheckedContinuation { continuation in
            PHImageManager.default().requestImage(
                for: asset,
                targetSize: Self.thumbnailTargetSize,
                contentMode: .aspectFit,
                options: options
            ) { image, _ in
                // deliveryMode .highQualityFormat calls back exactly once.
                continuation.resume(
                    returning: image?.cgImage(forProposedRect: nil, context: nil, hints: nil)
                )
            }
        }
    }
}
