import Foundation
import AppKit

public struct ClipboardItemNameHelper {
    static func generateImageName(data: Data?) -> String {
        if let data = data, let image = NSImage(data: data) {
            let size = image.size
            let width = Int(size.width)
            let height = Int(size.height)
            return "Zdjęcie \(width)×\(height)"
        }
        return "Zdjęcie"
    }
    static func generateFileName(content: String) -> String {
        let url = URL(string: content)
        let fileName = url?.lastPathComponent ?? content
        if let fileExtension = url?.pathExtension, !fileExtension.isEmpty {
            return fileName
        }
        if content.hasSuffix("/") {
            return fileName + "/"
        }
        return fileName
    }
    static func generateURLName(content: String) -> String {
        guard let url = URL(string: content) else { return content }
        if !url.pathExtension.isEmpty {
            return url.lastPathComponent
        }
        if let host = url.host {
            return host
        }
        return content
    }
    static func generateTextName(content: String) -> String {
        let maxLength = 50
        if content.count <= maxLength {
            return content
        } else {
            let truncated = String(content.prefix(maxLength))
            return truncated + "..."
        }
    }
    static func generateRichTextName(content: String) -> String {
        return generateTextName(content: content)
    }
} 