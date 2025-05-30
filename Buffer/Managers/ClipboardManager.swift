import Foundation
import AppKit
import Combine

class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()
    @Published var items: [ClipboardItem] = []
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private var lastContent: String?
    
    init() {
        startMonitoring()
        loadSavedItems()
    }
    
    private func startMonitoring() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
        RunLoop.current.add(timer!, forMode: .common)
    }
    
    private func checkClipboard() {
        let changeCount = NSPasteboard.general.changeCount
        guard changeCount != lastChangeCount else { return }
        
        lastChangeCount = changeCount
        
        // Check for text
        if let string = NSPasteboard.general.string(forType: .string) {
            guard string != lastContent else { return }
            lastContent = string
            
            if let url = URL(string: string), url.scheme != nil {
                let item = ClipboardItem(content: string, type: .url)
                addItem(item)
            } else {
                let item = ClipboardItem(content: string, type: .text)
                addItem(item)
            }
            saveItems()
        }
        
        // Check for images
        if let imageData = NSPasteboard.general.data(forType: .tiff) {
            let item = ClipboardItem(content: "Image", type: .image, data: imageData)
            addItem(item)
            saveItems()
        }
        
        // Check for files
        if let files = NSPasteboard.general.pasteboardItems?.compactMap({ $0.string(forType: .fileURL) }) {
            for file in files {
                let item = ClipboardItem(content: file, type: .file)
                addItem(item)
            }
            saveItems()
        }
        
        // Check for rich text
        if let rtf = NSPasteboard.general.data(forType: .rtf) {
            if let rtfString = String(data: rtf, encoding: .utf8) {
                let item = ClipboardItem(content: rtfString, type: .richText)
                addItem(item)
                saveItems()
            }
        }
    }
    
    private func addItem(_ item: ClipboardItem) {
        DispatchQueue.main.async {
            // Remove duplicate items (except pinned ones)
            self.items.removeAll { $0.content == item.content && !$0.isPinned }
            self.items.insert(item, at: 0)
            
            // Keep only last 25 unpinned items
            let pinnedItems = self.items.filter { $0.isPinned }
            let unpinnedItems = self.items.filter { !$0.isPinned }
            if unpinnedItems.count > 25 {
                self.items = pinnedItems + Array(unpinnedItems.prefix(25))
            }
        }
    }
    
    func copyItem(_ item: ClipboardItem) {
        NSPasteboard.general.clearContents()
        
        switch item.type {
        case .text, .url:
            NSPasteboard.general.setString(item.content, forType: .string)
        case .image:
            if let data = item.data {
                NSPasteboard.general.setData(data, forType: .tiff)
            }
        case .file:
            if let url = URL(string: item.content) {
                NSPasteboard.general.setString(url.path, forType: .fileURL)
            }
        case .richText:
            if let data = item.data {
                NSPasteboard.general.setData(data, forType: .rtf)
            }
        }
    }
    
    func removeItem(_ item: ClipboardItem) {
        DispatchQueue.main.async {
            self.items.removeAll { $0.id == item.id }
            self.saveItems()
        }
    }
    
    func togglePin(_ item: ClipboardItem) {
        DispatchQueue.main.async {
            if let index = self.items.firstIndex(where: { $0.id == item.id }) {
                self.items[index].isPinned.toggle()
                self.saveItems()
            }
        }
    }
    
    func clearAll() {
        DispatchQueue.main.async {
            self.items.removeAll { !$0.isPinned }
            self.saveItems()
        }
    }
    
    // MARK: - Persistence
    
    private func saveItems() {
        if let encoded = try? JSONEncoder().encode(items) {
            UserDefaults.standard.set(encoded, forKey: "savedClipboardItems")
        }
    }
    
    private func loadSavedItems() {
        if let savedData = UserDefaults.standard.data(forKey: "savedClipboardItems"),
           let decodedItems = try? JSONDecoder().decode([ClipboardItem].self, from: savedData) {
            items = decodedItems
        }
    }
    
    deinit {
        timer?.invalidate()
    }
} 