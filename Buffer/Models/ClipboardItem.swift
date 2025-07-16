import Foundation
import AppKit

struct ClipboardItem: Identifiable, Codable {
    let id: UUID
    let content: String
    let type: ClipboardItemType
    let timestamp: Date
    var isPinned: Bool
    var data: Data?
    
    init(content: String, type: ClipboardItemType, data: Data? = nil) {
        self.id = UUID()
        self.content = content
        self.type = type
        self.timestamp = Date()
        self.isPinned = false
        self.data = data
    }
    
    // Funkcja do generowania czytelnej nazwy wyświetlanej
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
    
    // Usunięto metody generateImageName, generateFileName, generateURLName, generateTextName, generateRichTextName
    
    // Funkcja do pobierania rozszerzenia pliku
    var fileExtension: String? {
        switch type {
        case .file:
            return URL(string: content)?.pathExtension
        case .image:
            if let data = data {
                // Sprawdź typ obrazu na podstawie danych
                if data.starts(with: [0xFF, 0xD8, 0xFF]) {
                    return "jpg"
                } else if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
                    return "png"
                } else if data.starts(with: [0x47, 0x49, 0x46]) {
                    return "gif"
                }
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
    
    // Funkcja do pobierania koloru dla typu
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