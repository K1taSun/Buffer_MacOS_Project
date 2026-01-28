import Foundation
import AppKit
import SwiftUI
import SwiftUI
import os
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
    
    // Logger
    private let logger = Logger(subsystem: "com.buffer.macos", category: "Shortcuts")
    
    @Published var shortcut: SavedShortcut? {
        didSet {
            saveShortcut()
        }
    }
    
    @Published var isRecording = false
    private var recordingMonitor: Any?
    
    private let shortcutKey = "savedGlobalShortcut"
    
    private init() {
        loadShortcut()
    }
    
    func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        
        recordingMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self = self else { return event }
            
            // Cancel on Escape
            if event.keyCode == 53 {
                self.stopRecording()
                return nil
            }
            
            self.setShortcut(event: event)
            self.stopRecording()
            return nil
        }
    }
    
    func stopRecording() {
        isRecording = false
        if let monitor = recordingMonitor {
            NSEvent.removeMonitor(monitor)
            recordingMonitor = nil
        }
    }
    
    func setShortcut(event: NSEvent) {
        

        
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
        let key = Int(event.keyCode)
        let chars = event.charactersIgnoringModifiers
        
        self.shortcut = SavedShortcut(keyCode: key, modifiers: modifiers, characters: chars)
    }
    
    func matches(_ event: NSEvent) -> Bool {
        // If we are recording, nothing should match as a hotkey to trigger actions
        if isRecording { return false }

        // Custom shortcut (priority)
        if let shortcut = shortcut {
            let eventModifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask)
            let shortcutModifiers = shortcut.modifierFlags.intersection(.deviceIndependentFlagsMask)
            
            let keyMatch = event.keyCode == shortcut.keyCode
            let modMatch = eventModifiers == shortcutModifiers
            
            logger.debug("Checking custom: Event(\(event.keyCode), \(eventModifiers.rawValue)) vs Shortcut(\(shortcut.keyCode), \(shortcutModifiers.rawValue)) -> Key:\(keyMatch) Mod:\(modMatch)")
            
            return keyMatch && modMatch
        }
        
        // Default fallback: Cmd + Shift + V (only if no custom shortcut is set)
        let isDefault = event.modifierFlags.contains([.command, .shift]) && event.keyCode == 9
        if isDefault {
             logger.debug("Matched default shortcut Cmd+Shift+V")
        }
        return isDefault
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
