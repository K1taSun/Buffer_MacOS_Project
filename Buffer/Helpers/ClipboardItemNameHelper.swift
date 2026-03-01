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
            let files = content.components(separatedBy: "\n").filter { !$0.isEmpty }
            let count = files.count
            
            if count > 0 {
                let firstFile = URL(fileURLWithPath: files[0]).lastPathComponent
                let firstFileTruncated = firstFile.count > 20 ? String(firstFile.prefix(20)) + "..." : firstFile
                
                if count > 1 {
                    return "\(count) Files: \(firstFileTruncated)"
                }
            }
        }
        
        let url = URL(fileURLWithPath: content)
        let fileName = url.lastPathComponent
        
        if fileName.isEmpty || fileName == "/" {
            return content.hasSuffix("/") ? "Folder" : "File"
        }
        
        return fileName
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
// Old code (for reference):
//         if data.starts(with: [0xFF, 0xD8, 0xFF]) {
//             return "JPEG"
//         } else if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
//             return "PNG"
//         } else if data.starts(with: [0x47, 0x49, 0x46]) {
//             return "GIF"
//         } else if data.starts(with: [0x52, 0x49, 0x46, 0x46]) {
//             return "WebP"
//         } else if data.starts(with: [0x00, 0x00, 0x01, 0x00]) {
//             return "ICO"
//         } else {
//             return "TIFF"
//         }

        // Keep the old logic but restructure to be slightly flatter
        if data.starts(with: [0xFF, 0xD8, 0xFF]) { return "JPEG" }
        if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return "PNG" }
        if data.starts(with: [0x47, 0x49, 0x46]) { return "GIF" }
        if data.starts(with: [0x52, 0x49, 0x46, 0x46]) { return "WebP" }
        if data.starts(with: [0x00, 0x00, 0x01, 0x00]) { return "ICO" }
        
        return "TIFF"
    }
    
    
    public static let supportedImageExtensions: Set<String> = [
        "png", "jpeg", "jpg", "jpe", "jif", "jfif", "jfi", "gif", "webp", "heic", "heif", "tiff", "tif", 
        "bmp", "dib", "ico", "tga", "icb", "vda", "vst", "avif", "jxl", "jp2", "j2k", "jpf", "jpm", "jpg2", 
        "j2c", "jpc", "jpx", "mj2", "bpg", "exr", "hdr", "pcx", "pbm", "pgm", "ppm", "pnm", "pam", "dds", 
        "cin", "dpx", "fits", "fit", "fts", "flif", "iff", "lbm", "mng", "pnr", "rle", "sgi", "rgb", "rgba", 
        "bw", "int", "inta", "vtf", "xbm", "xpm", "raw", "cr2", "cr3", "crw", "nef", "nrw", "arw", "srf", 
        "sr2", "pef", "ptx", "raf", "dng", "erf", "x3f", "orf", "rw2", "rwl", "kdc", "dcr", "k25", "srw", 
        "mef", "mrw", "mdc", "cap", "iiq", "eip", "3fr", "fff", "svg", "svgz", "ai", "eps", "pdf", "cdr", 
        "psd", "psb", "xcf", "afphoto", "afdesign", "cpt", "kra", "mdp", "pdn", "sai", "clip", "cpl", "cgm", 
        "emf", "wmf", "dxf", "dwg", "pict", "pct", "pic", "wbp", "mac", "pnt", "pntg", "qti", "qtif", "sct", "vml"
    ]
    
    // Sprawdza rozszerzenie
    public static func isImageExtension(_ ext: String) -> Bool {
        return supportedImageExtensions.contains(ext.lowercased())
    }
    

    public static let supportedVideoExtensions: Set<String> = [
        "mp4", "mov", "avi", "mkv", "wmv", "flv", "webm", "m4v", "mpeg", "mpg",
        "3gp", "3g2", "ts", "mts", "m2ts", "vob", "ogv", "f4v", "rm", "rmvb",
        "divx", "xvid", "asf", "mxf", "dv", "qt", "amv", "svi", "yuv", "m2v",
        "mp2", "mpe", "mpv", "m4p", "m4b"
    ]
    
    //--||--
    public static func isVideoExtension(_ ext: String) -> Bool {
        return supportedVideoExtensions.contains(ext.lowercased())
    }
    
    static func generateVideoName(content: String) -> String {
        let firstPath = content.components(separatedBy: "\n").first ?? content
        let fileName = URL(fileURLWithPath: firstPath).lastPathComponent
        return fileName.isEmpty ? "Video" : fileName
    }
} 