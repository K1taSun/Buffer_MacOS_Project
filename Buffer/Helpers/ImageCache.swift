import Foundation
import AppKit
import CoreGraphics

final class ImageCache {
    static let shared = ImageCache()
    private let cache = NSCache<NSString, NSImage>()
    
    private init() {
        // Limit cache size to prevent RAM bloat
        cache.countLimit = 150
    }
    
    /// Loads a downsampled thumbnail from a file URL asynchronously.
    func loadThumbnail(for url: URL, targetSize: CGFloat = 88.0, completion: @escaping (NSImage?) -> Void) {
        let cacheKey = url.path as NSString
        
        // Return from cache immediately if available
        if let cachedImage = cache.object(forKey: cacheKey) {
            completion(cachedImage)
            return
        }
        
        // Downsample on a background queue
        DispatchQueue.global(qos: .userInitiated).async {
            guard let imageSource = CGImageSourceCreateWithURL(url as CFURL, nil) else {
                DispatchQueue.main.async { completion(nil) }
                return
            }
            
            // Options to create a highly optimized, small thumbnail
            let options: [CFString: Any] = [
                kCGImageSourceCreateThumbnailFromImageIfAbsent: true,
                kCGImageSourceCreateThumbnailFromImageAlways: true,
                kCGImageSourceThumbnailMaxPixelSize: targetSize,
                kCGImageSourceShouldCacheImmediately: true
            ]
            
            if let cgImage = CGImageSourceCreateThumbnailAtIndex(imageSource, 0, options as CFDictionary) {
                let nsImage = NSImage(cgImage: cgImage, size: NSSize(width: cgImage.width, height: cgImage.height))
                self.cache.setObject(nsImage, forKey: cacheKey)
                
                DispatchQueue.main.async { completion(nsImage) }
            } else {
                DispatchQueue.main.async { completion(nil) }
            }
        }
    }
    
    /// Pre-caches an already created NSImage (e.g., from direct clipboard copy)
    func cacheImage(_ image: NSImage, for key: String) {
        cache.setObject(image, forKey: key as NSString)
    }
    
    /// Clears the cache
    func clear() {
        cache.removeAllObjects()
    }
}
