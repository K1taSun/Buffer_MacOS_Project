import Foundation

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
} 