import Foundation
import SwiftUI
import Combine

enum AppLanguage: String, CaseIterable, Identifiable {
    case english = "en"
    case polish = "pl"
    
    var id: String { self.rawValue }
    
    var displayName: String {
        switch self {
        case .english: return "English"
        case .polish: return "Polski"
        }
    }
}

// Prosty, scentralizowany system tłumaczeń (bez wymuszania restartu OSX na natywnym bundle'u)
final class LanguageManager: ObservableObject {
    static let shared = LanguageManager()
    
    // Automatycznie zapisuje/czyta z UserDefaults i publishuje zmiany dla UI
    @AppStorage("appLanguage") var currentLanguage: AppLanguage = .english {
        willSet {
            // Ręczny trigger potrzebny dla pełnego upewnienia się, że odświeży całe drzewo widoków
            objectWillChange.send()
        }
    }
    
    private init() {
        setupTranslations()
    }
    
    private var translations: [AppLanguage: [String: String]] = [:]
    
    // Default fallback dictionaries generated to disk if not found
    private let defaultEnglish: [String: String] = [
        "settings.title": "Settings", "settings.language": "Language", "settings.globalShortcut": "Global Shortcut",
        "settings.recording": "Recording... Press keys", "settings.defaultShortcut": "⌘⇧V (Default)", "settings.done": "Done",
        "settings.launchAtLogin": "Launch at login",
        "clipboard.title": "Clipboard History", "clipboard.search": "Search", "clipboard.itemsCount": "items",
        "clipboard.clearUnpinned": "Clear Unpinned", "clipboard.clearAll": "Clear All", "clipboard.copied": "Copied!",
        "filter.all": "All", "filter.text": "Text", "filter.images": "Images", "filter.videos": "Videos",
        "filter.files": "Files", "filter.urls": "URLs", "filter.pinned": "Pinned",
        "empty.noFound": "No items found", "empty.noClipboard": "No clipboard items", "empty.noText": "No text items",
        "empty.noImages": "No images", "empty.noVideos": "No videos", "empty.noFiles": "No files", "empty.noUrls": "No URLs",
        "empty.noPinned": "No pinned items", "emptySub.trySearch": "Try adjusting your search terms",
        "emptySub.copyStart": "Copy something to get started", "emptySub.copyText": "Copy some text to see it here",
        "emptySub.copyImage": "Copy an image to see it here", "emptySub.copyVideo": "Copy a video file to see it here",
        "emptySub.copyFile": "Copy a file to see it here", "emptySub.copyUrl": "Copy a URL to see it here",
        "emptySub.pinItems": "Pin items to keep them here", "date.today": "Today", "date.yesterday": "Yesterday",
        "date.past": "Past", "context.copy": "Copy", "context.pin": "Pin", "context.unpin": "Unpin",
        "context.delete": "Delete", "context.close": "Close"
    ]
    
    private let defaultPolish: [String: String] = [
        "settings.title": "Ustawienia", "settings.language": "Język", "settings.globalShortcut": "Globalny Skrót Kl.",
        "settings.recording": "Nagrywanie... Naciśnij klawisze", "settings.defaultShortcut": "⌘⇧V (Domyślny)", "settings.done": "Gotowe",
        "settings.launchAtLogin": "Uruchamiaj przy starcie",
        "clipboard.title": "Historia Schowka", "clipboard.search": "Szukaj", "clipboard.itemsCount": "elementów",
        "clipboard.clearUnpinned": "Wyczyść nieprzypięte", "clipboard.clearAll": "Wyczyść wszystko", "clipboard.copied": "Skopiowano!",
        "filter.all": "Kaskada", "filter.text": "Tekst", "filter.images": "Zdjęcia", "filter.videos": "Nagrania",
        "filter.files": "Pliki", "filter.urls": "Linki", "filter.pinned": "Przypięte",
        "empty.noFound": "Nie znaleziono elementów", "empty.noClipboard": "Brak elementów w schowku", "empty.noText": "Brak tekstu",
        "empty.noImages": "Brak obrazków", "empty.noVideos": "Brak nagrań", "empty.noFiles": "Brak plików", "empty.noUrls": "Brak linków",
        "empty.noPinned": "Brak przypiętych", "emptySub.trySearch": "Spróbuj skrócić lub zmienić frazę wyszukiwania.",
        "emptySub.copyStart": "Skopiuj coś, aby zacząć.", "emptySub.copyText": "Skopiuj jakiś tekst, aby się tu pojawił.",
        "emptySub.copyImage": "Skopiuj obrazek, aby się tu pojawił.", "emptySub.copyVideo": "Skopiuj plik wideo z Findera, aby się tu pojawił.",
        "emptySub.copyFile": "Skopiuj plik z Findera, aby się tu pojawił.", "emptySub.copyUrl": "Strzel w jakiś link, by go tu wrzucić.",
        "emptySub.pinItems": "Możesz przypiąć istotne dla Ciebie elementy, aby tu wisiały.", "date.today": "Dzisiaj",
        "date.yesterday": "Wczoraj", "date.past": "Przeszłe", "context.copy": "Kopiuj", "context.pin": "Przypnij",
        "context.unpin": "Odepnij", "context.delete": "Usuń", "context.close": "Zamknij"
    ]
    
    private var translationsDirectoryURL: URL? {
        let fileManager = FileManager.default
        guard let appSupportURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else { return nil }
        let bufferDir = appSupportURL.appendingPathComponent("Buffer", isDirectory: true)
        let translationsDir = bufferDir.appendingPathComponent("Translations", isDirectory: true)
        
        if !fileManager.fileExists(atPath: translationsDir.path) {
            do {
                try fileManager.createDirectory(at: translationsDir, withIntermediateDirectories: true, attributes: nil)
            } catch {
                print("🚨 Failed to create Translations directory: \(error)")
                return nil
            }
        }
        return translationsDir
    }

    private func setupTranslations() {
        guard let dirURL = translationsDirectoryURL else {
            // Fallback to memory defaults
            translations[.english] = defaultEnglish
            translations[.polish] = defaultPolish
            return
        }
        
        loadOrGenerateLanguageFile(for: .english, defaultData: defaultEnglish, in: dirURL)
        loadOrGenerateLanguageFile(for: .polish, defaultData: defaultPolish, in: dirURL)
    }
    
    private func loadOrGenerateLanguageFile(for language: AppLanguage, defaultData: [String: String], in dirURL: URL) {
        let fileURL = dirURL.appendingPathComponent("\(language.id).json")
        let fileManager = FileManager.default
        
        if !fileManager.fileExists(atPath: fileURL.path) {
            do {
                let data = try JSONEncoder().encode(defaultData)
                try data.write(to: fileURL)
                translations[language] = defaultData
            } catch {
                print("🚨 Failed to write default \(language.id).json to disk: \(error)")
                translations[language] = defaultData
            }
        } else {
            do {
                let data = try Data(contentsOf: fileURL)
                var dict = try JSONDecoder().decode([String: String].self, from: data)
                
                
                var hasMissingKeys = false
                for (key, value) in defaultData {
                    if dict[key] == nil {
                        dict[key] = value
                        hasMissingKeys = true
                    }
                }
                
                
                if hasMissingKeys {
                    let updatedData = try JSONEncoder().encode(dict)
                    try updatedData.write(to: fileURL)
                }
                
                translations[language] = dict
            } catch {
                print("🚨 Failed to read \(language.id).json from disk, using fallback: \(error)")
                translations[language] = defaultData
            }
        }
    }
    
    func localized(_ key: String) -> String {
        // Fallback do angielskiego klucza zamiast wyrzucania błędów, klasyka
        if let text = translations[currentLanguage]?[key] {
            return text
        }
        
        // Zabezpieczenie deweloperskie w razie zgubienia czegoś w dictionary
        return translations[.english]?[key] ?? "[\(key)]"
    }
}
