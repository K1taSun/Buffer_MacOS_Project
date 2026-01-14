import Foundation
import AppKit
import Combine
import CryptoKit

private enum Config {
    static let maxItems = 50
    static let checkInterval: TimeInterval = 0.5 // Zwiększone z 0.3 dla lepszej wydajności
    static let savedItemsKey = "savedClipboardItems"
    static let typeSortOrder: [ClipboardItemType: Int] = [
        .text: 0,
        .url: 1,
        .file: 2,
        .image: 3,
        .richText: 4
    ]
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
    
    private init() {
        startMonitoring()
        loadSavedItems()
    }
    
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
        // Optymalizacja: sprawdzaj w kolejności prawdopodobieństwa użycia
        if processStringContent() { return }
        if processImageContent() { return }
        if processFileContent() { return }
        if processRichTextContent() { return }
    }
    
    private func processImageContent() -> Bool {
        guard let imageData = NSPasteboard.general.data(forType: .tiff) else { return false }
        
        let imageHash = imageData.sha256()
        guard imageHash != lastImageHash else { return true }
        lastImageHash = imageHash
        
        let imageType = imageData.imageType
        let item = ClipboardItem(content: "Image.\(imageType.rawValue)", type: .image, data: imageData)
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
        guard let files = NSPasteboard.general.pasteboardItems?.compactMap({ $0.string(forType: .fileURL) }), !files.isEmpty else { return false }
        
        for file in files {
            let item = ClipboardItem(content: file, type: .file)
            addItem(item)
        }
        saveItems()
        return true
    }
    
    private func processRichTextContent() -> Bool {
        guard let rtfData = NSPasteboard.general.data(forType: .rtf),
              let rtfString = String(data: rtfData, encoding: .utf8) else { return false }
        
        let item = ClipboardItem(content: rtfString, type: .richText, data: rtfData)
        addItem(item)
        saveItems()
        return true
    }
    
    func addItem(_ item: ClipboardItem) {
        performOnMain {
            if let pinnedIndex = self.items.firstIndex(where: { $0.content == item.content && $0.isPinned }) {
                if let data = item.data {
                    self.items[pinnedIndex].data = data
                }
                return
            }
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
        performOnMain {
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
            self.items.removeAll()
            self.resetClipboardTracking()
            self.saveItems()
        }
    }
    
    func clearUnpinned() {
        performOnMain {
            self.items.removeAll { !$0.isPinned }
            self.saveItems()
        }
    }
    
    func saveItems() {
        // Opóźnione zapisywanie - batch saves dla lepszej wydajności
        saveWorkItem?.cancel()
        
        let workItem = DispatchWorkItem { [weak self] in
            guard let self = self else { return }
            let snapshot = self.performOnMain { self.items }
            DispatchQueue.global(qos: .utility).async {
                do {
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
                let decodedItems = try JSONDecoder().decode([ClipboardItem].self, from: savedData)
                performOnMain {
                    self.items = decodedItems
                    self.lastContent = decodedItems.first(where: { $0.type == .text || $0.type == .url })?.content
                    if let imageData = decodedItems.first(where: { $0.type == .image })?.data {
                        self.lastImageHash = imageData.sha256()
                    } else {
                        self.lastImageHash = nil
                    }
                    self.lastChangeCount = NSPasteboard.general.changeCount
                }
            }
        } catch {
            print("Error loading saved clipboard items: \(error)")
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
    
    private func detectImageType(from data: Data) -> String {
        data.imageType.rawValue
    }
    
    private func detectFileType(from path: String) -> ClipboardItemType {
        .file
    }

    private func sortItemsByFormat(_ items: inout [ClipboardItem]) {
        items.sort { lhs, rhs in
            let lhsKey = sortKey(for: lhs)
            let rhsKey = sortKey(for: rhs)

            if lhsKey.typeRank != rhsKey.typeRank {
                return lhsKey.typeRank < rhsKey.typeRank
            }

            let formatComparison = lhsKey.formatKey.localizedCaseInsensitiveCompare(rhsKey.formatKey)
            if formatComparison != .orderedSame {
                return formatComparison == .orderedAscending
            }

            if lhs.timestamp != rhs.timestamp {
                return lhs.timestamp > rhs.timestamp
            }

            return lhs.content.localizedCaseInsensitiveCompare(rhs.content) == .orderedAscending
        }
    }

    private func sortKey(for item: ClipboardItem) -> (typeRank: Int, formatKey: String) {
        let typeRank = Config.typeSortOrder[item.type] ?? Int.max
        let formatKey = formatSortKey(for: item)
        return (typeRank, formatKey)
    }

    private func formatSortKey(for item: ClipboardItem) -> String {
        switch item.type {
        case .file:
            let rawContent = item.content
            if let url = URL(string: rawContent) {
                let ext = url.pathExtension
                if !ext.isEmpty { return ext.lowercased() }
                return url.lastPathComponent.lowercased()
            }
            let sanitized = rawContent.hasPrefix("file://")
                ? String(rawContent.dropFirst("file://".count))
                : rawContent
            let fallbackURL = URL(fileURLWithPath: sanitized)
            let ext = fallbackURL.pathExtension
            if !ext.isEmpty { return ext.lowercased() }
            let lastPath = fallbackURL.lastPathComponent
            return lastPath.isEmpty ? "zzz" : lastPath.lowercased()
        case .image:
            if let data = item.data {
                return detectImageType(from: data).lowercased()
            }
            return "image"
        case .url:
            return URL(string: item.content)?.scheme?.lowercased() ?? "url"
        case .text:
            return "text"
        case .richText:
            return "richtext"
        }
    }

    private func normalizeItemOrdering() {
        let pinnedItems = items.filter { $0.isPinned }
        var unpinnedItems = items.filter { !$0.isPinned }

        sortItemsByFormat(&unpinnedItems)

        if unpinnedItems.count > Config.maxItems {
            unpinnedItems = Array(unpinnedItems.prefix(Config.maxItems))
        }

        items = pinnedItems + unpinnedItems
    }

    private func performOnMain(_ block: () -> Void) {
        if Thread.isMainThread {
            block()
        } else {
            DispatchQueue.main.sync(execute: block)
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
    
    enum ImageType: String {
        case jpg, png, gif, webp, tiff
    }

    var imageType: ImageType {
        if self.starts(with: [0xFF, 0xD8, 0xFF]) { return .jpg }
        if self.starts(with: [0x89, 0x50, 0x4E, 0x47]) { return .png }
        if self.starts(with: [0x47, 0x49, 0x46]) { return .gif }
        if self.starts(with: [0x52, 0x49, 0x46, 0x46]) { return .webp }
        return .tiff
    }
} 