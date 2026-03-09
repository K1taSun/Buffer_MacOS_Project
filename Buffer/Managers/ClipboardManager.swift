import Foundation
import AppKit
import Combine
import CryptoKit
import UniformTypeIdentifiers

private enum Config {
    static let maxItems = 1024
    static let checkInterval: TimeInterval = 0.5
    static let savedItemsKey = "savedClipboardItems"

}

final class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()
    @Published var items: [ClipboardItem] = []
    
    private var timer: Timer?
    private var pasteboard: NSPasteboard = .general
    private var lastChangeCount: Int = 0
    private var lastContent: String?
    private var lastImageHash: String?
    private var pollingTask: Task<Void, Never>?
    private var isProcessing = false
    private var saveWorkItem: DispatchWorkItem?
    
    // Czas ostatniego odświeżenia UI - żebyśmy wiedzieli, kiedy wymusić nowy podział na dni/godziny.
    // Przydatne, żeby widok przebudował np. sekcję "Dzisiaj" na "Wczoraj" bez dodawania nowego pliku.
    private var lastUIUpdateDate: Date = Date()
    
    private let fileManager = FileManager.default
    
    private init() {
        createImagesDirectoryIfNeeded()
        setupPolling()
        loadSavedItems()
    }
    
    deinit {
        pollingTask?.cancel()
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
        do {
            try fileManager.createDirectory(at: url, withIntermediateDirectories: true, attributes: nil)
        } catch {
            print("🚨 [Storage] CRITICAL: Failed to create images directory: \(error)")
        }
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
        do {
            return try Data(contentsOf: fileURL)
        } catch {
            print("🚨 [Storage] ERROR: Failed to load image \(fileName) from disk: \(error)")
            return nil
        }
    }
    
    private func deleteImageFromDisk(fileName: String) {
        guard let imagesDir = imagesDirectoryURL else { return }
        let fileURL = imagesDir.appendingPathComponent(fileName)
        do {
            if fileManager.fileExists(atPath: fileURL.path) {
                try fileManager.removeItem(at: fileURL)
            }
        } catch {
            print("🚨 [Storage] ERROR: Failed to delete image \(fileName): \(error)")
        }
    }
    
    // MARK: - Monitoring
    
    private func setupPolling() {
        // Poll every 0.75s using a yielding Task to improve battery efficiency vs raw RunLoop Timers
        pollingTask = Task { [weak self] in
            while !Task.isCancelled {
                self?.checkForChanges()
                try? await Task.sleep(nanoseconds: 750_000_000)
            }
        }
    }
    
    private func checkForChanges() {
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
    
    // Wymusza odświeżenie SwiftUI u użytkownika w widokach, gdy zmieni się dzień lub upłynie godzina. 
    // Dzięki temu elementy prawidłowo "przeskakują" do sekcji takich jak "Wczoraj",
    // bez potrzeby "szturchania" schowka nowym plikiem.
    private func triggerUIRefreshIfNeeded() {
        let now = Date()
        let calendar = Calendar.current
        
        // Szybki check: omijamy przebudowę UI dopóki nie zmieni się konkretna godzina lub nie przeskoczy dzień.
        let isNewDay = !calendar.isDate(now, inSameDayAs: lastUIUpdateDate)
        let hasHourPassed = calendar.component(.hour, from: now) != calendar.component(.hour, from: lastUIUpdateDate)
        
        let needsRefresh = isNewDay || hasHourPassed
        guard needsRefresh else { return }
        
        lastUIUpdateDate = now
        
        performOnMain { [weak self] in
            // Wysyłamy cichy sygnał widokom, że obiekty (groupedItems) mogą wymagać przegrupowania.
            self?.objectWillChange.send()
        }
    }
    
    // Helper to get source app
    private func getSourceApp() -> String? {
        // We use the frontmost application which typically represents what the user just copied from.
        return NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }
    
    private func processClipboardContent() {
        // OLD CODE (for reference):
        /*
        if processImageContent() { return }
        if processVideoContent() { return }
        if processFileContent() { return }
        if processStringContent() { return }
        if processRichTextContent() { return }
        */
        
        let pb = NSPasteboard.general
        let sourceApp = getSourceApp()
        
        // Let's rely on explicit UTIs first
        // 1. Check for files/media dragged from finder (which give file URLs)
        if processFileURLs(from: pb, sourceApp: sourceApp) { return }
        
        // 2. Check for explicit image data in memory (like a screenshot)
        if processImageContent(from: pb, sourceApp: sourceApp) { return }
        
        // 3. Rich text
        if processRichTextContent(from: pb, sourceApp: sourceApp) { return }
        
        // 4. Plain text fallback
        if processStringContent(from: pb, sourceApp: sourceApp) { return }
    }
    
    private func processFileURLs(from pb: NSPasteboard, sourceApp: String?) -> Bool {
        let options: [NSPasteboard.ReadingOptionKey: Any] = [.urlReadingFileURLsOnly: true]
        guard let urls = pb.readObjects(forClasses: [NSURL.self], options: options) as? [URL],
              !urls.isEmpty else { return false }
        
        let combinedPaths = urls.map { $0.path }.joined(separator: "\n")
        
        // Duplication check against last state
        if combinedPaths == lastContent { return true }
        lastContent = combinedPaths
        
        // Differentiate Type based on the first file's UTI
        guard let firstURL = urls.first else { return false }
        let type = determineType(for: firstURL)
        
        let item = ClipboardItem(
            contentPayload: combinedPaths,
            type: type,
            sourceApp: sourceApp
        )
        
        addItem(item)
        saveItems()
        return true
    }
    
    private func determineType(for url: URL) -> ClipboardItemType {
        if #available(macOS 11.0, *) {
            guard let resourceValues = try? url.resourceValues(forKeys: [.contentTypeKey]),
                  let utType = resourceValues.contentType else {
                return determineTypeFallback(for: url)
            }
            
            if utType.conforms(to: .image) { return .image }
            if utType.conforms(to: .movie) || utType.conforms(to: .video) { return .video }
            if utType.conforms(to: .audio) { return .audio }
            
            return .file
        } else {
            guard let typeId = try? url.resourceValues(forKeys: [.typeIdentifierKey]).typeIdentifier else {
                return determineTypeFallback(for: url)
            }
            
            let cfType = typeId as CFString
            if UTTypeConformsTo(cfType, "public.image" as CFString) { return .image }
            if UTTypeConformsTo(cfType, "public.movie" as CFString) { return .video }
            if UTTypeConformsTo(cfType, "public.audio" as CFString) { return .audio }
            
            return .file
        }
    }
    
    private func determineTypeFallback(for url: URL) -> ClipboardItemType {
        let ext = url.pathExtension.lowercased()
        if ClipboardItemNameHelper.isImageExtension(ext) { return .image }
        if ClipboardItemNameHelper.isVideoExtension(ext) { return .video }
        if ClipboardItemNameHelper.isAudioExtension(ext) { return .audio }
        return .file
    }
    
    private func processImageContent(from pb: NSPasteboard, sourceApp: String?) -> Bool {
        guard let imageData = pb.data(forType: .tiff) ?? pb.data(forType: .png) else { return false }
        
        let imageHash = imageData.sha256()
        guard imageHash != lastImageHash else { return true }
        lastImageHash = imageHash
        
        let imagePath = saveImageToDisk(imageData)
        
        // detect type using helper
        let format = ClipboardItemNameHelper.detectImageFormat(from: imageData)
        
        // Try to get a meaningful name if copied from browser / file instead of pure graphics buffer
        var contentName = "Image.\(format)"
        if let urlString = pb.string(forType: .fileURL) ?? pb.string(forType: .URL),
           let url = URL(string: urlString),
           !url.lastPathComponent.isEmpty {
            contentName = url.lastPathComponent
        } else if let stringData = pb.string(forType: .string), stringData.count < 100, !stringData.contains("\n") {
            contentName = stringData
        }
        
        let item = ClipboardItem(
            contentPayload: contentName,
            type: .image,
            data: imageData, // Set data for immediate UI use
            contentPreview: imagePath,
            sourceApp: sourceApp
        )
        
        addItem(item)
        saveItems()
        return true
    }
    
    private func processStringContent(from pb: NSPasteboard, sourceApp: String?) -> Bool {
        guard let string = pb.string(forType: .string) else { return false }
        
        guard string != lastContent else { return true }
        lastContent = string
        
        let trimmedString = string.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedString.isEmpty, trimmedString.count > 1 else { return true }
        
        let item = ClipboardItem(
            contentPayload: trimmedString,
            type: .text,
            sourceApp: sourceApp
        )
        
        addItem(item)
        saveItems()
        return true
    }
    
    private func processRichTextContent(from pb: NSPasteboard, sourceApp: String?) -> Bool {
        guard let rtfData = pb.data(forType: .rtf) else { return false }
        
        // Wyciągamy czysty tekst z RTF, żeby nie wyświetlać użytkownikowi i nie przekazywać
        // w payloadzie surowego kodu w stylu {\rtf1\ansi...}
        let plainText: String
        if let attrStr = NSAttributedString(rtf: rtfData, documentAttributes: nil) {
            plainText = attrStr.string
        } else if let rtfString = String(data: rtfData, encoding: .utf8) {
            plainText = rtfString
        } else {
            return false
        }
        
        let trimmedString = plainText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmedString.isEmpty else { return false }
        
        guard plainText != lastContent else { return true }
        lastContent = plainText
        
        // For rich text, we store data in memory (it's small usually) or we could refactor similarly if needed.
        let item = ClipboardItem(
            contentPayload: plainText,
            type: .richText,
            data: rtfData,
            sourceApp: sourceApp
        )
        
        addItem(item)
        saveItems()
        return true
    }
    
    func addItem(_ item: ClipboardItem) {
        performOnMain {
            // // Old code (for reference): Duplicate handling was previously removing duplicates instead of bumping them up.
            
            // Check if duplicate exists based on payload or image preview path
            let duplicateIndex = self.items.firstIndex { existing in
                if item.type == .image {
                    return existing.contentPreview != nil && existing.contentPreview == item.contentPreview
                }
                return existing.contentPayload == item.contentPayload
            }
            
            if let index = duplicateIndex {
                // It's a duplicate - bump timestamp to now so it rises to the top, preserve pinned state
                self.items[index].timestamp = Date()
                self.items[index].data = item.data // refreshed cache
                self.items[index].contentPreview = item.contentPreview
                // We do NOT change `isPinned` state, if it was pinned it stays pinned!
            } else {
                // New item
                self.items.insert(item, at: 0)
            }
            
            self.normalizeItemOrdering()
        }
    }
    
    func copyItem(_ item: ClipboardItem) {
        NSPasteboard.general.clearContents()
        
        switch item.type {
        case .text:
            NSPasteboard.general.setString(item.contentPayload, forType: .string)
        case .image:
            if let data = item.data {
                NSPasteboard.general.setData(data, forType: .tiff)
            }
        case .file:
            // Split content back into paths
            let paths = item.contentPayload.components(separatedBy: "\n")
            let urls = paths.map { URL(fileURLWithPath: $0) as NSURL }
            NSPasteboard.general.writeObjects(urls)
        case .richText:
            if let data = item.data {
                NSPasteboard.general.setData(data, forType: .rtf)
            }
        case .video, .audio:
            let mediaURL = URL(fileURLWithPath: item.contentPayload) as NSURL
            NSPasteboard.general.writeObjects([mediaURL])
        }
    }
    
    func removeItem(_ item: ClipboardItem) {
        performOnMain {
            // Delete image file if exists
            if let previewPath = item.contentPreview {
                self.deleteImageFromDisk(fileName: previewPath)
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
                if let previewPath = item.contentPreview {
                    self.deleteImageFromDisk(fileName: previewPath)
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
                if let previewPath = item.contentPreview {
                    self.deleteImageFromDisk(fileName: previewPath)
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
                    // This will encode items according to new CodingKeys in ClipboardItem
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
                    if decodedItems[i].type == .image, let path = decodedItems[i].contentPreview {
                         decodedItems[i].data = self.loadImageFromDisk(fileName: path)
                    }
                }
                
                performOnMain {
                    self.items = decodedItems
                    self.lastContent = decodedItems.first(where: { $0.type == .text })?.contentPayload
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
                if let previewPath = item.contentPreview {
                    deleteImageFromDisk(fileName: previewPath)
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