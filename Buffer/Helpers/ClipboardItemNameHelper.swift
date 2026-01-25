import Foundation
import AppKit

public struct ClipboardItemNameHelper {
    static func generateImageName(data: Data?) -> String {
        guard let data = data else { return "Image" }
        
        let image = NSImage(data: data)
        guard let image = image else { return "Image" }
        
        let size = image.size
        let width = Int(size.width)
        let height = Int(size.height)
        
        let format = detectImageFormat(from: data)
        return "\(format) Image \(width)×\(height)"
    }
    
    static func generateFileName(content: String) -> String {
        guard !content.isEmpty else { return "File" }
        
        // Handle multiple files
        if content.contains("\n") {
            let files = content.components(separatedBy: "\n")
            let count = files.count
            let firstFile = URL(fileURLWithPath: files[0]).lastPathComponent
            let firstFileTruncated = firstFile.count > 20 ? String(firstFile.prefix(20)) + "..." : firstFile
            if count > 1 {
                return "\(count) Files: \(firstFileTruncated)..."
            }
        }
        
        let url = URL(fileURLWithPath: content)
        let fileName = url.lastPathComponent
        
        if content.hasSuffix("/") {
            return fileName.isEmpty ? "Folder" : fileName
        }
        
        return fileName.isEmpty ? "File" : fileName
    }
    
    static func generateURLName(content: String) -> String {
        guard !content.isEmpty else { return "URL" }
        
        guard let url = URL(string: content) else { 
            return content.count > 30 ? String(content.prefix(30)) + "..." : content 
        }
        
        if url.scheme == "file" {
            return url.lastPathComponent.isEmpty ? "File" : url.lastPathComponent
        }
        
        if !url.pathExtension.isEmpty {
            return url.lastPathComponent
        }
        
        if let host = url.host {
            return host
        }
        
        return content.count > 30 ? String(content.prefix(30)) + "..." : content
    }
    
    static func generateTextName(content: String) -> String {
        guard !content.isEmpty else { return "Empty Text" }
        
        let maxLength = 50
        let trimmedContent = content.trimmingCharacters(in: .whitespacesAndNewlines)
        
        if trimmedContent.isEmpty {
            return "Empty Text"
        }
        
        if trimmedContent.count <= maxLength {
            return trimmedContent
        } else {
            let truncated = String(trimmedContent.prefix(maxLength))
            return truncated + "..."
        }
    }
    
    static func generateRichTextName(content: String) -> String {
        return generateTextName(content: content)
    }
    
    public static func detectImageFormat(from data: Data) -> String {
        if data.starts(with: [0xFF, 0xD8, 0xFF]) {
            return "JPEG"
        } else if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return "PNG"
        } else if data.starts(with: [0x47, 0x49, 0x46]) {
            return "GIF"
        } else if data.starts(with: [0x52, 0x49, 0x46, 0x46]) {
            return "WebP"
        } else if data.starts(with: [0x00, 0x00, 0x01, 0x00]) {
            return "ICO"
        } else {
            return "TIFF"
        }
    }
} 