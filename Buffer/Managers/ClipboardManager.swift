import Foundation
import AppKit
import Combine
import CryptoKit

private enum Config {
    static let maxItems = 50
    static let checkInterval: TimeInterval = 0.5
    static let savedItemsKey = "savedClipboardItems"

}

final class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()
    @Published var items: [ClipboardItem] = []
    
    private var timer: Timer?
    private var lastChangeCount: Int = 0
    private var lastContent: String?
    private var lastImageHash: String?
    private var isProcessing = false
    private var saveWorkItem: DispatchWorkItem?
    
    private let fileManager = FileManager.default
    
    private init() {
        createImagesDirectoryIfNeeded()
        startMonitoring()
        loadSavedItems()
    }
    
    // MARK: - File System Helpers
    
    private var imagesDirectoryURL: URL? {
        guard let appSupport = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {
            return nil
        }
        let bufferURL = appSupport.appendingPathComponent("Buffer", isDirectory: true)
        let imagesURL = bufferURL.appendingPathComponent("Images", isDirectory: true)
        return imagesURL
    }
    
    private func createImagesDirectoryIfNeeded() {
        guard let url = imagesDirectoryURL else { return }
        try? fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
    }
    
    private func saveImageToDisk(_ data: Data) -> String? {
        guard let imagesDir = imagesDirectoryURL else { return nil }
        let fileName = UUID().uuidString
        let fileURL = imagesDir.appendingPathComponent(fileName)
        
        do {
            try data.write(to: fileURL)
            return fileName
        } catch {
            print("Error saving image to disk: \(error)")
            return nil
        }
    }
    
    private func loadImageFromDisk(fileName: String) -> Data? {
        guard let imagesDir = imagesDirectoryURL else { return nil }
        let fileURL = imagesDir.appendingPathComponent(fileName)
        return try? Data(contentsOf: fileURL)
    }
    
    private func deleteImageFromDisk(fileName: String) {
        guard let imagesDir = imagesDirectoryURL else { return }
        let fileURL = imagesDir.appendingPathComponent(fileName)
        try? fileManager.removeItem(at: fileURL)
    }
    
    // MARK: - Monitoring
    
    private func startMonitoring() {
        stopMonitoring()
        
        timer = Timer.scheduledTimer(withTimeInterval: Config.checkInterval, repeats: true) { [weak self] _ in
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
        
        let changeCount = NSPasteboard.general.changeCount
        guard changeCount != lastChangeCount else {
            return
        }
        
        isProcessing = true
        lastChangeCount = changeCount
        
        DispatchQueue.global(qos: .utility).async { [weak self] in
            self?.processClipboardContent()
            DispatchQueue.main.async {
                self?.isProcessing = false
            }
        }
    }
    
    private func processClipboardContent() {
        // Check for files first, as some apps put both file and string representations
        if processFileContent() { return }
        if processImageContent() { return }
        if processStringContent() { return }
        if processRichTextContent() { return }
    }
    
    private func processImageContent() -> Bool {
        guard let imageData = NSPasteboard.general.data(forType: .tiff) else { return false }
        
        let imageHash = imageData.sha256()
        guard imageHash != lastImageHash else { return true }
        lastImageHash = imageHash
        
        // Save image to disk
        let imagePath = saveImageToDisk(imageData)
        
        // detect type using helper
        let format = ClipboardItemNameHelper.detectImageFormat(from: imageData)
        
        let item = ClipboardItem(
            content: "Image.\(format)",
            type: .image,
            data: imageData, // Set data for immediate UI use
            imagePath: imagePath
        )
        
        addItem(item)
        saveItems()
        return true
    }
    
    private func processStringContent() -> Bool {
        guard let string = NSPasteboard.general.string(forType: .string) else { return false }
        
        guard string != lastContent else { return true }
        lastContent = string
        
        let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedString.isEmpty, trimmedString.count > 1 else { return true }
        
        let item: ClipboardItem
        if let url = URL(string: trimmedString), url.scheme != nil {
            item = ClipboardItem(content: trimmedString, type: .url)
        } else {
            item = ClipboardItem(content: trimmedString, type: .text)
        }
        
        addItem(item)
        saveItems()
        return true
    }
    
    private func processFileContent() -> Bool {
        guard let urls = NSPasteboard.general.readObjects(forClasses: [NSURL.self], options: nil) as? [URL],
              !urls.isEmpty else { return false }
        
        // Filter for file URLs
        let fileURLs = urls.filter { $0.isFileURL }
        guard !fileURLs.isEmpty else { return false }
        
        // Combine paths with newlines to store multiple files in one item
        let combinedPaths = fileURLs.map { $0.path }.joined(separator: "\n")
        
        // Check if this is a duplicate of the last processed content to avoid loops
        // (We use a simple check, though files don't usually jitter like logic might)
        if combinedPaths == lastContent { return true }
        lastContent = combinedPaths
        
        let item = ClipboardItem(content: combinedPaths, type: .file)
        addItem(item)
        saveItems()
        return true
    }
    
    private func processRichTextContent() -> Bool {
        guard let rtfData = NSPasteboard.general.data(forType: .rtf),
              let rtfString = String(data: rtfData, encoding: .utf8) else { return false }
        
        // For rich text, we store data in memory (it's small usually) or we could refactor similarly if needed.
        // Assuming RTF is small enough for now, but to be consistent with Item model, we pass data.
        let item = ClipboardItem(content: rtfString, type: .richText, data: rtfData)
        addItem(item)
        saveItems()
        return true
    }
    
    func addItem(_ item: ClipboardItem) {
        performOnMain {
            // Check for duplicate pinned items
            if let pinnedIndex = self.items.firstIndex(where: { $0.content == item.content && $0.isPinned }) {
                // Update existing pinned item
                self.items[pinnedIndex].data = item.data
                self.items[pinnedIndex].imagePath = item.imagePath // Update path if changed
                return
            }
            // Remove unpinned duplicates
            self.items.removeAll { $0.content == item.content && !$0.isPinned }
            self.items.insert(item, at: 0)
            
            self.normalizeItemOrdering()
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
            // Split content back into paths
            let paths = item.content.components(separatedBy: "\n")
            let urls = paths.map { URL(fileURLWithPath: $0) as NSURL }
            NSPasteboard.general.writeObjects(urls)
        case .richText:
            if let data = item.data {
                NSPasteboard.general.setData(data, forType: .rtf)
            }
        }
    }
    
    func removeItem(_ item: ClipboardItem) {
        performOnMain {
            // Delete image file if exists
            if let imagePath = item.imagePath {
                self.deleteImageFromDisk(fileName: imagePath)
            }
            
            self.items.removeAll { $0.id == item.id }
            self.saveItems()
        }
    }
    
    func togglePin(_ item: ClipboardItem) {
        performOnMain {
            if let index = self.items.firstIndex(where: { $0.id == item.id }) {
                self.items[index].isPinned.toggle()
                self.normalizeItemOrdering()
                self.saveItems()
            }
        }
    }
    
    func clearAll() {
        performOnMain {
            // Cleanup all image files
            for item in self.items {
                if let imagePath = item.imagePath {
                    self.deleteImageFromDisk(fileName: imagePath)
                }
            }
            
            self.items.removeAll()
            self.resetClipboardTracking()
            self.saveItems()
        }
    }
    
    func clearUnpinned() {
        performOnMain {
            // Cleanup unpinned image files
            for item in self.items where !item.isPinned {
                if let imagePath = item.imagePath {
                    self.deleteImageFromDisk(fileName: imagePath)
                }
            }
            
            self.items.removeAll { !$0.isPinned }
            self.saveItems()
        }
    }
    
    func saveItems() {
        saveWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            let snapshot = self.performOnMain { self.items }
            DispatchQueue.global(qos: .utility).async {
                do {
                    // This will encode items. ClipboardItem.encode skips 'data', only saving 'imagePath'
                    let encoded = try JSONEncoder().encode(snapshot)
                    UserDefaults.standard.set(encoded, forKey: Config.savedItemsKey)
                } catch {
                    print("Error saving clipboard items: \(error)")
                }
            }
        }
        
        saveWorkItem = workItem
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5, execute: workItem)
    }
    
    func loadSavedItems() {
        do {
            if let savedData = UserDefaults.standard.data(forKey: Config.savedItemsKey) {
                var decodedItems = try JSONDecoder().decode([ClipboardItem].self, from: savedData)
                
                // Hydrate data from disk for images
                for i in 0..<decodedItems.count {
                    if decodedItems[i].type == .image, let path = decodedItems[i].imagePath {
                         decodedItems[i].data = self.loadImageFromDisk(fileName: path)
                    }
                }
                
                performOnMain {
                    self.items = decodedItems
                    self.lastContent = decodedItems.first(where: { $0.type == .text || $0.type == .url })?.content
                    if let imageItem = decodedItems.first(where: { $0.type == .image }), let data = imageItem.data {
                        self.lastImageHash = data.sha256()
                    } else {
                        self.lastImageHash = nil
                    }
                    self.lastChangeCount = NSPasteboard.general.changeCount
                }
            }
        } catch {
            print("Error loading saved clipboard items: \(error)")
            // If decoding fails (maybe old format without imagePath logic?), clear history to be safe
            UserDefaults.standard.removeObject(forKey: Config.savedItemsKey)
        }
    }
    
    deinit {
        stopMonitoring()
    }
    
    private func resetClipboardTracking() {
        lastContent = nil
        lastImageHash = nil
        lastChangeCount = NSPasteboard.general.changeCount
    }
    
    private func normalizeItemOrdering() {
        let pinnedItems = items.filter { $0.isPinned }
        var unpinnedItems = items.filter { !$0.isPinned }

        // Sort items by recency (newest first)
        unpinnedItems.sort { $0.timestamp > $1.timestamp }

        if unpinnedItems.count > Config.maxItems {
            // Make sure to delete files for items that are dropping off the list!
            let itemsToRemove = unpinnedItems.dropFirst(Config.maxItems)
            for item in itemsToRemove {
                if let imagePath = item.imagePath {
                    deleteImageFromDisk(fileName: imagePath)
                }
            }
            unpinnedItems = Array(unpinnedItems.prefix(Config.maxItems))
        }

        items = pinnedItems + unpinnedItems
    }

    private func performOnMain(_ block: @escaping () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.async(execute: block) // Changed to async to avoid potential deadlocks
        }
    }
    
    private func performOnMain<T>(_ block: () -> T) -> T {
        if Thread.isMainThread {
            return block()
        } else {
            var result: T!
            DispatchQueue.main.sync {
                result = block()
            }
            return result
        }
    }
}

extension Data {
    func sha256() -> String {
        let hash = SHA256.hash(data: self)
        return hash.compactMap { String(format: "%02x", $0) }.joined()
    }
} 