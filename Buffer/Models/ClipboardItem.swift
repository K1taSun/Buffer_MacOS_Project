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
        case .url:
            return ClipboardItemNameHelper.generateURLName(content: content)
        case .text:
            return ClipboardItemNameHelper.generateTextName(content: content)
        case .richText:
            return ClipboardItemNameHelper.generateRichTextName(content: content)
        }
    }
    
    var fileExtension: String? {
        switch type {
        case .file:
            return URL(string: content)?.pathExtension
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
    case url
    case richText
    
    var icon: String {
        switch self {
        case .text: return "doc.text"
        case .image: return "photo"
        case .file: return "doc"
        case .url: return "link"
        case .richText: return "doc.richtext"
        }
    }
    
    var color: String {
        switch self {
        case .text: return "blue"
        case .image: return "green"
        case .file: return "orange"
        case .url: return "purple"
        case .richText: return "indigo"
        }
    }
}

extension ClipboardItem {
    var itemProvider: NSItemProvider {
        switch type {
        case .text:
            return NSItemProvider(object: content as NSString)
        case .url:
            if let url = URL(string: content) {
                return NSItemProvider(object: url as NSURL)
            }
            return NSItemProvider(object: content as NSString)
        case .image:
            if let data = data, let image = NSImage(data: data) {
                return NSItemProvider(object: image)
            }
            return NSItemProvider()
        case .file:
            if let url = URL(string: content) {
                return NSItemProvider(object: url as NSURL)
            }
            return NSItemProvider(object: content as NSString)
        case .richText:
            // For rich text, we provide it as plain text for compatibility
            // or we could implement proper RTF support if needed
            return NSItemProvider(object: content as NSString)
        }
    }
}
