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
            return generateImageName()
        case .file:
            return generateFileName()
        case .url:
            return generateURLName()
        case .text:
            return generateTextName()
        case .richText:
            return generateRichTextName()
        }
    }
    
    // Generuje nazwę dla zdjęcia
    private func generateImageName() -> String {
        if let data = data {
            // Sprawdź rozmiar obrazu
            if let image = NSImage(data: data) {
                let size = image.size
                let width = Int(size.width)
                let height = Int(size.height)
                return "Zdjęcie \(width)×\(height)"
            }
        }
        return "Zdjęcie"
    }
    
    // Generuje nazwę dla pliku
    private func generateFileName() -> String {
        let url = URL(string: content)
        let fileName = url?.lastPathComponent ?? content
        
        // Jeśli to jest plik z rozszerzeniem, pokaż rozszerzenie
        if let fileExtension = url?.pathExtension, !fileExtension.isEmpty {
            return fileName
        }
        
        // Jeśli to folder, dodaj "/" na końcu
        if content.hasSuffix("/") {
            return fileName + "/"
        }
        
        return fileName
    }
    
    // Generuje nazwę dla URL
    private func generateURLName() -> String {
        guard let url = URL(string: content) else { return content }
        
        // Jeśli to plik, użyj nazwy pliku
        if !url.pathExtension.isEmpty {
            return url.lastPathComponent
        }
        
        // Dla stron internetowych, pokaż domenę
        if let host = url.host {
            return host
        }
        
        return content
    }
    
    // Generuje nazwę dla tekstu
    private func generateTextName() -> String {
        let maxLength = 50
        if content.count <= maxLength {
            return content
        } else {
            let truncated = String(content.prefix(maxLength))
            return truncated + "..."
        }
    }
    
    // Generuje nazwę dla rich text
    private func generateRichTextName() -> String {
        return generateTextName()
    }
    
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