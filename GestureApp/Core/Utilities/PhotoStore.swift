import Foundation
import UIKit

/// Persists user-picked images on disk so they survive app restarts
/// even when the backend is not configured yet.
///
/// Files live under `Documents/profile_photos/` and are returned as
/// `file://` URLs — SwiftUI's `AsyncImage` can load them directly.
enum PhotoStore {

    /// Target width for avatars; keeps files small (~150–300 KB JPEG)
    /// while still looking crisp on retina screens.
    private static let maxDimension: CGFloat = 1024
    private static let jpegQuality: CGFloat = 0.85

    enum StoreError: Error {
        case encodingFailed
    }

    static func saveAvatar(_ data: Data) throws -> URL {
        let jpeg = try encodeAsJPEG(data)
        let directory = try avatarsDirectory()
        let filename = "avatar-\(UUID().uuidString).jpg"
        let url = directory.appendingPathComponent(filename)
        try jpeg.write(to: url, options: .atomic)
        return url
    }

    static func deleteIfLocal(_ url: URL) {
        guard url.isFileURL else { return }
        try? FileManager.default.removeItem(at: url)
    }

    // MARK: - Private

    private static func avatarsDirectory() throws -> URL {
        let fm = FileManager.default
        let docs = try fm.url(
            for: .documentDirectory,
            in: .userDomainMask,
            appropriateFor: nil,
            create: true
        )
        let dir = docs.appendingPathComponent("profile_photos", isDirectory: true)
        if !fm.fileExists(atPath: dir.path) {
            try fm.createDirectory(at: dir, withIntermediateDirectories: true)
        }
        return dir
    }

    private static func encodeAsJPEG(_ data: Data) throws -> Data {
        guard let image = UIImage(data: data) else {
            throw StoreError.encodingFailed
        }
        let resized = downscale(image, to: maxDimension)
        guard let jpeg = resized.jpegData(compressionQuality: jpegQuality) else {
            throw StoreError.encodingFailed
        }
        return jpeg
    }

    private static func downscale(_ image: UIImage, to maxSide: CGFloat) -> UIImage {
        let size = image.size
        let longest = max(size.width, size.height)
        guard longest > maxSide else { return image }

        let scale = maxSide / longest
        let target = CGSize(width: size.width * scale, height: size.height * scale)

        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 1
        let renderer = UIGraphicsImageRenderer(size: target, format: format)
        return renderer.image { _ in
            image.draw(in: CGRect(origin: .zero, size: target))
        }
    }
}
