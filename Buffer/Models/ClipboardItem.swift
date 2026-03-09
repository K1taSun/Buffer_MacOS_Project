import Foundation
import AppKit

// OLD CODE (for reference):
/*
struct ClipboardItem: Identifiable, Codable {
    let id: UUID
    let content: String
    let type: ClipboardItemType
    let timestamp: Date
    var isPinned: Bool
    var imagePath: String?
    
    // Data is not encoded/decoded automatically
    var data: Data?
    ...
}
*/

struct ClipboardItem: Identifiable, Codable {
    let id: UUID
    var timestamp: Date
    let type: ClipboardItemType
    var contentPreview: String?
    let contentPayload: String
    var isPinned: Bool
    var sourceApp: String?
    
    // Data is not encoded/decoded automatically. Used for short-term caching.
    var data: Data?
    
    enum CodingKeys: String, CodingKey {
        case id
        case timestamp
        case type
        case contentPreview = "content_preview"
        case contentPayload = "content_payload"
        case isPinned = "is_pinned"
        case sourceApp = "source_app"
    }
    
    init(contentPayload: String, type: ClipboardItemType, data: Data? = nil, contentPreview: String? = nil, sourceApp: String? = nil) {
        self.id = UUID()
        self.contentPayload = contentPayload
        self.type = type
        self.timestamp = Date()
        self.isPinned = false
        self.data = data
        self.contentPreview = contentPreview
        self.sourceApp = sourceApp
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        
        // Handle current structure
        if container.contains(.contentPayload) {
            id = try container.decode(UUID.self, forKey: .id)
            timestamp = try container.decode(Date.self, forKey: .timestamp)
            type = try container.decode(ClipboardItemType.self, forKey: .type)
            contentPreview = try container.decodeIfPresent(String.self, forKey: .contentPreview)
            contentPayload = try container.decode(String.self, forKey: .contentPayload)
            isPinned = try container.decode(Bool.self, forKey: .isPinned)
            sourceApp = try container.decodeIfPresent(String.self, forKey: .sourceApp)
        } else {
            // // Old code fallback (for reference):
            // Fallback for old structure migration (content, imagePath)
            enum LegacyKeys: String, CodingKey {
                case id, content, type, timestamp, isPinned, imagePath
            }
            let legacyContainer = try decoder.container(keyedBy: LegacyKeys.self)
            
            id = try legacyContainer.decode(UUID.self, forKey: .id)
            let oldContent = try legacyContainer.decode(String.self, forKey: .content)
            contentPayload = oldContent
            type = try legacyContainer.decode(ClipboardItemType.self, forKey: .type)
            timestamp = try legacyContainer.decode(Date.self, forKey: .timestamp)
            isPinned = try legacyContainer.decode(Bool.self, forKey: .isPinned)
            contentPreview = try legacyContainer.decodeIfPresent(String.self, forKey: .imagePath)
            sourceApp = nil // Did not exist previously
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(timestamp, forKey: .timestamp)
        try container.encode(type, forKey: .type)
        try container.encodeIfPresent(contentPreview, forKey: .contentPreview)
        try container.encode(contentPayload, forKey: .contentPayload)
        try container.encode(isPinned, forKey: .isPinned)
        try container.encodeIfPresent(sourceApp, forKey: .sourceApp)
    }
    
    var displayName: String {
        switch type {
        case .image:
            if !contentPayload.starts(with: "Image.") {
                return ClipboardItemNameHelper.generateFileName(content: contentPayload)
            }
            return ClipboardItemNameHelper.generateImageName(data: data)
        case .file:
            return ClipboardItemNameHelper.generateFileName(content: contentPayload)
        case .text:
            return ClipboardItemNameHelper.generateTextName(content: contentPayload)
        case .richText:
            return ClipboardItemNameHelper.generateRichTextName(content: contentPayload)
        case .video:
            return ClipboardItemNameHelper.generateVideoName(content: contentPayload)
        case .audio:
            return ClipboardItemNameHelper.generateAudioName(content: contentPayload)
        }
    }
    
    var fileExtension: String? {
        switch type {
        case .file, .video, .audio:
            let firstPath = contentPayload.components(separatedBy: "\n").first ?? contentPayload
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
    case audio
    
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
        case .audio: return "waveform"
        }
    }
    
    var color: String {
        switch self {
        case .text: return "blue"
        case .image: return "green"
        case .file: return "orange"
        case .richText: return "indigo"
        case .video: return "red"
        case .audio: return "purple"
        }
    }
}

extension ClipboardItem {
    var itemProvider: NSItemProvider {
        let provider = NSItemProvider()
        
        switch type {
        case .text:
            provider.registerObject(contentPayload as NSString, visibility: .all)
            
        case .image:
            if let data = data, let image = NSImage(data: data) {
                provider.registerObject(image, visibility: .all)
            }
            
        case .file:
            // Handle multiple files
            let paths = contentPayload.components(separatedBy: "\n").filter { !$0.isEmpty }
            
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
                provider.registerObject(contentPayload as NSString, visibility: .all)
            }
            
        case .richText:
            // Apple's WebKit has a known sandbox bug when dragging raw RTF data (`public.rtf`) via NSItemProvider,
            // treating it as a file drop (hence the WebKitDropDestination permission error).
            // Additionally, NSAttributedString does not natively conform to NSItemProviderWriting on macOS.
            // The cleanest and most professional fallback for Drag & Drop is exporting plain text (`NSString`), 
            // while full RTF formatting remains fully supported for regular Copy/Paste (`copyItem`).
            provider.registerObject(contentPayload as NSString, visibility: .all)
            
        case .video, .audio:
            // Media is stored as a path on disk — just hand it over as a file URL, same as .file
            let mediaURL = URL(fileURLWithPath: contentPayload)
            provider.registerObject(mediaURL as NSURL, visibility: .all)
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
