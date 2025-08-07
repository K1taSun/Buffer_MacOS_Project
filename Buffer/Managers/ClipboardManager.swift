import Foundation
import AppKit
import Combine
import CryptoKit

class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()
    @Published var items: [ClipboardItem] = []
    
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private var lastContent: String?
    private var lastImageHash: String?
    private var isProcessing = false
    private let maxItems = 50
    private let checkInterval: TimeInterval = 0.3
    private var cancellables = Set<AnyCancellable>()
    
    private init() {
        startMonitoring()
        loadSavedItems()
    }
    
    private func startMonitoring() {
        stopMonitoring()
        
        timer = Timer.scheduledTimer(withTimeInterval: checkInterval, repeats: true) { [weak self] _ in
            self?.checkClipboard()
        }
        
        if let timer = timer {
            RunLoop.current.add(timer, forMode: .common)
        }
    }
    
    private func stopMonitoring() {
        timer?.invalidate()
        timer = nil
    }
    
    private func checkClipboard() {
        guard !isProcessing else { return }
        isProcessing = true
        
        let changeCount = NSPasteboard.general.changeCount
        guard changeCount != lastChangeCount else {
            isProcessing = false
            return
        }
        
        lastChangeCount = changeCount
        
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.processClipboardContent()
            DispatchQueue.main.async {
                self?.isProcessing = false
            }
        }
    }
    
    private func processClipboardContent() {
        if let imageData = NSPasteboard.general.data(forType: .tiff) {
            let imageHash = imageData.sha256()
            guard imageHash != lastImageHash else { return }
            lastImageHash = imageHash
            
            let imageType = detectImageType(from: imageData)
            let item = ClipboardItem(content: "Image.\(imageType)", type: .image, data: imageData)
            addItem(item)
            saveItems()
            return
        }
        
        if let string = NSPasteboard.general.string(forType: .string) {
            guard string != lastContent else { return }
            lastContent = string
            
            guard !string.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  string.count > 1 else { return }
            
            let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
            
            if let url = URL(string: trimmedString), url.scheme != nil {
                let item = ClipboardItem(content: trimmedString, type: .url)
                addItem(item)
            } else {
                let item = ClipboardItem(content: trimmedString, type: .text)
                addItem(item)
            }
            saveItems()
            return
        }
        
        if let files = NSPasteboard.general.pasteboardItems?.compactMap({ $0.string(forType: .fileURL) }) {
            for file in files {
                let fileType = detectFileType(from: file)
                let item = ClipboardItem(content: file, type: fileType)
                addItem(item)
            }
            saveItems()
            return
        }
        
        if let rtf = NSPasteboard.general.data(forType: .rtf) {
            if let rtfString = String(data: rtf, encoding: .utf8) {
                let item = ClipboardItem(content: rtfString, type: .richText, data: rtf)
                addItem(item)
                saveItems()
            }
        }
    }
    
    private func addItem(_ item: ClipboardItem) {
        DispatchQueue.main.async {
            self.items.removeAll { $0.content == item.content && !$0.isPinned }
            self.items.insert(item, at: 0)
            
            let pinnedItems = self.items.filter { $0.isPinned }
            let unpinnedItems = self.items.filter { !$0.isPinned }
            if unpinnedItems.count > self.maxItems {
                self.items = pinnedItems + Array(unpinnedItems.prefix(self.maxItems))
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
    
    func clearUnpinned() {
        DispatchQueue.main.async {
            self.items.removeAll { !$0.isPinned }
            self.saveItems()
        }
    }
    
    private func saveItems() {
        do {
            let encoded = try JSONEncoder().encode(items)
            UserDefaults.standard.set(encoded, forKey: "savedClipboardItems")
        } catch {
            print("Error saving clipboard items: \(error)")
        }
    }
    
    private func loadSavedItems() {
        do {
            if let savedData = UserDefaults.standard.data(forKey: "savedClipboardItems") {
                let decodedItems = try JSONDecoder().decode([ClipboardItem].self, from: savedData)
                items = decodedItems
            }
        } catch {
            print("Error loading saved clipboard items: \(error)")
            // Clear corrupted data
            UserDefaults.standard.removeObject(forKey: "savedClipboardItems")
        }
    }
    
    deinit {
        stopMonitoring()
        cancellables.removeAll()
    }
    
    private func detectImageType(from data: Data) -> String {
        if data.starts(with: [0xFF, 0xD8, 0xFF]) {
            return "jpg"
        } else if data.starts(with: [0x89, 0x50, 0x4E, 0x47]) {
            return "png"
        } else if data.starts(with: [0x47, 0x49, 0x46]) {
            return "gif"
        } else if data.starts(with: [0x52, 0x49, 0x46, 0x46]) {
            return "webp"
        } else {
            return "tiff"
        }
    }
    
    private func detectFileType(from path: String) -> ClipboardItemType {
        let url = URL(string: path)
        let isDirectory = url?.hasDirectoryPath ?? false
        
        if isDirectory {
            return .file
        }
        
        return .file
    }
}

extension Data {
    func sha256() -> String {
        let hash = SHA256.hash(data: self)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
} 