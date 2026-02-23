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
        let provider = NSItemProvider()
        
        switch type {
        case .text:
            provider.registerObject(content as NSString, visibility: .all)
            
        case .url:
            if let url = URL(string: content) {
                provider.registerObject(url as NSURL, visibility: .all)
            }
            // Fallback for text consumers
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
        }
        
        return provider
    }
}

// MARK: - Date Grouping

enum DateSection: Int, CaseIterable {
// Old code (for reference):
//     case today
//     case yesterday
//     case twoDaysAgo
//     case past
//     
//     var title: String {
//         switch self {
//         case .today: return "Today"
//         case .yesterday: return "Yesterday"
//         case .twoDaysAgo: return "2 Days Ago"
//         case .past: return "Past"
//         }
//     }
//     
//     var titlePolish: String {
//         switch self {
//         case .today: return "Dzisiaj"
//         case .yesterday: return "Wczoraj"
//         case .twoDaysAgo: return "2 dni temu"
//         case .past: return "Przeszłe"
//         }
//     }

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
        let now = Date()
        let itemDate = timestamp
        
        // Check if today
        if calendar.isDateInToday(itemDate) {
            return .today
        }
        
        // Check if yesterday
        if calendar.isDateInYesterday(itemDate) {
            return .yesterday
        }
        
// Old code (for reference):
//         // Check if 2 days ago
//         if let twoDaysAgo = calendar.date(byAdding: .day, value: -2, to: calendar.startOfDay(for: now)),
//            calendar.isDate(itemDate, inSameDayAs: twoDaysAgo) {
//             return .twoDaysAgo
//         }
        
// Old code (for reference):
//         // Check if within last 30 days (last month)
//         if let thirtyDaysAgo = calendar.date(byAdding: .day, value: -30, to: now),
//            itemDate > thirtyDaysAgo {
//             return .lastMonth
//         }
//         
//         // Otherwise, it's from last year
//         return .lastYear

        // Wszystko inne zrzucamy do wspólnej przegródki reprezentującej przeszłość
        return .past
    }
}
