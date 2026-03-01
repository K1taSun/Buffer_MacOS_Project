import Foundation
import AppKit

struct ClipboardItem: Identifiable, Codable {
    let id: UUID
    let content: String
    let type: ClipboardItemType
    let timestamp: Date
    var isPinned: Bool
    var imagePath: String?
    
    // Data is not encoded/decoded automatically
    var data: Data?
    
    enum CodingKeys: String, CodingKey {
        case id, content, type, timestamp, isPinned, imagePath
    }
    
    init(content: String, type: ClipboardItemType, data: Data? = nil, imagePath: String? = nil) {
        self.id = UUID()
        self.content = content
        self.type = type
        self.timestamp = Date()
        self.isPinned = false
        self.data = data
        self.imagePath = imagePath
    }
    
    // Custom decoding to handle legacy data if needed, or just default
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        id = try container.decode(UUID.self, forKey: .id)
        content = try container.decode(String.self, forKey: .content)
        type = try container.decode(ClipboardItemType.self, forKey: .type)
        timestamp = try container.decode(Date.self, forKey: .timestamp)
        isPinned = try container.decode(Bool.self, forKey: .isPinned)
        imagePath = try container.decodeIfPresent(String.self, forKey: .imagePath)
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(content, forKey: .content)
        try container.encode(type, forKey: .type)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encode(imagePath, forKey: .imagePath)
    }
    
    var displayName: String {
        switch type {
        case .image:
            return ClipboardItemNameHelper.generateImageName(data: data)
        case .file:
            return ClipboardItemNameHelper.generateFileName(content: content)
        case .text:
            return ClipboardItemNameHelper.generateTextName(content: content)
        case .richText:
            return ClipboardItemNameHelper.generateRichTextName(content: content)
        case .video:
            return ClipboardItemNameHelper.generateVideoName(content: content)
        }
    }
    
    var fileExtension: String? {
        switch type {
        case .file, .video:
            // The content might be multiple paths separated by newlines
            let firstPath = content.components(separatedBy: "\n").first ?? content
            return URL(fileURLWithPath: firstPath).pathExtension
        case .image:
            if let data = data {
                return ClipboardItemNameHelper.detectImageFormat(from: data).lowercased()
            }
            return nil
        default:
            return nil
        }
    }
}

enum ClipboardItemType: String, Codable {
    case text
    case image
    case file
    case richText
    case video
    
    // Custom decoder so that legacy types (e.g. "url", which we dropped) don't blow up the JSON
    // deserialization and wipe the user's entire clipboard history on app restart.
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        let rawValue = try container.decode(String.self)
        self = ClipboardItemType(rawValue: rawValue) ?? .text
    }
    
    var icon: String {
        switch self {
        case .text: return "doc.text"
        case .image: return "photo"
        case .file: return "doc"
        case .richText: return "doc.richtext"
        case .video: return "film"
        }
    }
    
    var color: String {
        switch self {
        case .text: return "blue"
        case .image: return "green"
        case .file: return "orange"
        case .richText: return "indigo"
        case .video: return "red"
        }
    }
}

extension ClipboardItem {
    var itemProvider: NSItemProvider {
        let provider = NSItemProvider()
        
        switch type {
        case .text:
            provider.registerObject(content as NSString, visibility: .all)
            
        case .image:
            if let data = data, let image = NSImage(data: data) {
                provider.registerObject(image, visibility: .all)
            }
            
        case .file:
            // Handle multiple files
            let paths = content.components(separatedBy: "\n").filter { !$0.isEmpty }
            
            if !paths.isEmpty {
                // 1. Modern file URL support (for the first file - standard consumers)
                let fileURL = URL(fileURLWithPath: paths[0])
                provider.registerObject(fileURL as NSURL, visibility: .all)
                
                // 2. Legacy support for multiple files (Finder expects this for multi-file drops)
                // We use NSFilenamesPboardType (which maps to "NSFilenamesPboardType")
                provider.registerDataRepresentation(forTypeIdentifier: "NSFilenamesPboardType", visibility: .all) { completion in
                    do {
                        // Takes an array of strings
                        let data = try PropertyListSerialization.data(fromPropertyList: paths, format: .xml, options: 0)
                        completion(data, nil)
                    } catch {
                        completion(nil, error)
                    }
                    return nil
                }
            } else {
                provider.registerObject(content as NSString, visibility: .all)
            }
            
        case .richText:
            // 1. Register RTF data if available (preserves formatting)
            if let data = data {
                provider.registerDataRepresentation(forTypeIdentifier: NSPasteboard.PasteboardType.rtf.rawValue, visibility: .all) { completion in
                    completion(data, nil)
                    return nil
                }
            }
            
            // 2. Fallback to plain text
            provider.registerObject(content as NSString, visibility: .all)
            
        case .video:
            // Video is stored as a path on disk — just hand it over as a file URL, same as .file
            let videoURL = URL(fileURLWithPath: content)
            provider.registerObject(videoURL as NSURL, visibility: .all)
        }
        
        return provider
    }
}


enum DateSection: Int, CaseIterable {


    case today
    case yesterday
    case past
    
    var localizedKey: String {
        switch self {
        case .today: return "date.today"
        case .yesterday: return "date.yesterday"
        case .past: return "date.past"
        }
    }
}

extension ClipboardItem {
    /// Determines which date section this item belongs to based on its timestamp
    var dateSection: DateSection {
        let calendar = Calendar.current
        let itemDate = timestamp
        
        // Check if today
        if calendar.isDateInToday(itemDate) {
            return .today
        }
        
        // Check if yesterday
        if calendar.isDateInYesterday(itemDate) {
            return .yesterday
        }

        // Wszystko inne zrzucamy do wspólnej przegródki reprezentującej przeszłość
        return .past
    }
}
