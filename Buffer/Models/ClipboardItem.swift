import Foundation
import AppKit
import UniformTypeIdentifiers

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
        case .text, .richText:
            provider.registerObject(contentPayload as NSString, visibility: .all)
            
        case .image:
            // 1. App-to-App compatibility directly dropping visual NSImage (Notes, Freeform, etc.)
            let hasImageObject = (data != nil && NSImage(data: data!) != nil)
            if hasImageObject, let image = NSImage(data: data!) {
                provider.registerObject(image, visibility: .all)
            }
            
            // 2. File-system support: Finder expects files.
            // When dragged to Finder/Desktop, we need to create a temporary file.
            if let safeData = data {
                let safeName = self.displayName.trimmingCharacters(in: .whitespacesAndNewlines).replacingOccurrences(of: " ", with: "_")
                let ext = self.fileExtension ?? "png"
                let safeFileName = "\(safeName).\(ext)"
                
                // Suggested file name when dropping
                provider.suggestedName = safeFileName
                
                let utiType = UTType(filenameExtension: ext)?.identifier ?? "public.image"
                
                provider.registerFileRepresentation(forTypeIdentifier: utiType, visibility: .all) { completion in
                    do {
                        // We must write to a temporary location for the drag payload
                        let tempDir = FileManager.default.temporaryDirectory
                            .appendingPathComponent("BufferDragDrops", isDirectory: true)
                        
                        if !FileManager.default.fileExists(atPath: tempDir.path) {
                            try FileManager.default.createDirectory(at: tempDir, withIntermediateDirectories: true, attributes: nil)
                        }
                        
                        let tempFileURL = tempDir.appendingPathComponent(safeFileName)
                        try safeData.write(to: tempFileURL, options: .atomic)
                        
                        completion(tempFileURL, false, nil)
                    } catch {
                        completion(nil, false, error)
                    }
                    return nil
                }
            } else if contentPayload.starts(with: "/") || contentPayload.contains("file://") {
                // Obraz został skopiowany na zasadzie faktu istnienia pliku z Findera. Przekazujemy ścieżki.
                ClipboardItem.registerFiles(in: provider, from: contentPayload)
            } else {
                provider.registerObject(contentPayload as NSString, visibility: .all)
            }
            
        case .file, .video, .audio:
            // Te typy mocno opierają się na fakcie bycia linkami na dysku (contentPayload zawiera path/paths).
            ClipboardItem.registerFiles(in: provider, from: contentPayload)
        }
        
        return provider
    }
    
    // Helper function to extract and register file dependencies correctly (even multiple files)
    private static func registerFiles(in provider: NSItemProvider, from payload: String) {
        let paths = payload.components(separatedBy: "\n").filter { !$0.isEmpty }
        
        if paths.isEmpty {
            provider.registerObject(payload as NSString, visibility: .all)
            return
        }
        
        // 1. Modern file URL support (for the first file - standard consumers)
        let fileURL = URL(fileURLWithPath: paths[0])
        provider.registerObject(fileURL as NSURL, visibility: .all)
        
        // 2. Legacy support for multiple files/Finder expected type
        provider.registerDataRepresentation(forTypeIdentifier: "NSFilenamesPboardType", visibility: .all) { completion in
            do {
                let pdata = try PropertyListSerialization.data(fromPropertyList: paths, format: .xml, options: 0)
                completion(pdata, nil)
            } catch {
                completion(nil, error)
            }
            return nil
        }
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
