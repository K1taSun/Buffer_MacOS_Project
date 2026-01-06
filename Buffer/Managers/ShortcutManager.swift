import Foundation
import AppKit
import SwiftUI

struct SavedShortcut: Codable, Equatable {
    let keyCode: Int
    let modifiers: UInt
    let characters: String?
    
    var modifierFlags: NSEvent.ModifierFlags {
        NSEvent.ModifierFlags(rawValue: modifiers)
    }
    
    var displayString: String {
        var result = ""
        
        if modifierFlags.contains(.command) { result += "⌘" }
        if modifierFlags.contains(.shift) { result += "⇧" }
        if modifierFlags.contains(.option) { result += "⌥" }
        if modifierFlags.contains(.control) { result += "⌃" }
        
        if let chars = characters?.uppercased() {
            result += chars
        } else {
            result += String(UnicodeScalar(keyCode) ?? "?")
        }
        
        return result
    }
}

class ShortcutManager: ObservableObject {
    static let shared = ShortcutManager()
    
    @Published var shortcut: SavedShortcut? {
        didSet {
            saveShortcut()
        }
    }
    
    private let shortcutKey = "savedGlobalShortcut"
    
    private init() {
        loadShortcut()
    }
    
    func setShortcut(event: NSEvent) {
        
        guard event.keyCode < 0xF800 else { return } 
        
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
        let key = Int(event.keyCode)
        let chars = event.charactersIgnoringModifiers
        
        self.shortcut = SavedShortcut(keyCode: key, modifiers: modifiers, characters: chars)
    }
    
    func matches(_ event: NSEvent) -> Bool {
        guard let shortcut = shortcut else {
            // Default fallback if no shortcut is set: Cmd + Shift + V
            if event.modifierFlags.contains([.command, .shift]) && event.keyCode == 9 { // 9 is 'v'
                return true
            }
            return false
        }
        
        let eventModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
        let shortcutModifiers = shortcut.modifierFlags.intersection(.deviceIndependentFlagsMask)
        
        return event.keyCode == shortcut.keyCode && eventModifiers == shortcutModifiers
    }
    
    private func saveShortcut() {
        if let shortcut = shortcut,
           let data = try? JSONEncoder().encode(shortcut) {
            UserDefaults.standard.set(data, forKey: shortcutKey)
        } else {
            UserDefaults.standard.removeObject(forKey: shortcutKey)
        }
    }
    
    private func loadShortcut() {
        if let data = UserDefaults.standard.data(forKey: shortcutKey),
           let saved = try? JSONDecoder().decode(SavedShortcut.self, from: data) {
            self.shortcut = saved
        }
    }
}
