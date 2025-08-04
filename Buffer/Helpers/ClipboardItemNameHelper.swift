import Foundation
import AppKit

public struct ClipboardItemNameHelper {
    static func generateImageName(data: Data?) -> String {
        guard let data = data else { return "Image" }
        
        do {
            let image = NSImage(data: data)
            guard let image = image else { return "Image" }
            
            let size = image.size
            let width = Int(size.width)
            let height = Int(size.height)
            
            // Detect image format
            let format = detectImageFormat(from: data)
            return "\(format) Image \(width)×\(height)"
        } catch {
            return "Image"
        }
    }
    
    static func generateFileName(content: String) -> String {
        guard !content.isEmpty else { return "File" }
        
        let url = URL(string: content)
        let fileName = url?.lastPathComponent ?? content
        
        // Handle directory paths
        if content.hasSuffix("/") {
            return fileName.isEmpty ? "Folder" : fileName
        }
        
        // Handle files with extensions
        if let fileExtension = url?.pathExtension, !fileExtension.isEmpty {
            return fileName
        }
        
        return fileName.isEmpty ? "File" : fileName
    }
    
    static func generateURLName(content: String) -> String {
        guard !content.isEmpty else { return "URL" }
        
        guard let url = URL(string: content) else { 
            return content.count > 30 ? String(content.prefix(30)) + "..." : content 
        }
        
        // If it's a file URL, use the filename
        if url.scheme == "file" {
            return url.lastPathComponent.isEmpty ? "File" : url.lastPathComponent
        }
        
        // If it has a path extension, use the filename
        if !url.pathExtension.isEmpty {
            return url.lastPathComponent
        }
        
        // Use the host if available
        if let host = url.host {
            return host
        }
        
        // Fallback to truncated content
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
    
    // MARK: - Helper Methods
    
    private static func detectImageFormat(from data: Data) -> String {
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