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
            updateHotKey()
        }
    }
    
    @Published var isRecording = false
    private var recordingMonitor: Any?
    
    private let shortcutKey = "savedGlobalShortcut"
    
    private init() {
        loadShortcut()
        // Ensure hotkey is registered on launch
        updateHotKey()
    }
    
    func startRecording() {
        guard !isRecording else { return }
        isRecording = true
        
        // Disable hotkey while recording
        HotKeyManager.shared.unregisterHotkey()
        
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
        
        // Re-enable hotkey
        updateHotKey()
    }
    
    func setShortcut(event: NSEvent) {
        let modifiers = event.modifierFlags.intersection(.deviceIndependentFlagsMask).rawValue
        let key = Int(event.keyCode)
        let chars = event.charactersIgnoringModifiers
        
        self.shortcut = SavedShortcut(keyCode: key, modifiers: modifiers, characters: chars)
    }
    
    // Legacy matches method removed or kept for local fallback?
    // Carbon handles global, but local NSEvent might still be relevant if we wanted to
    // keep consistency. However, Carbon works locally too.
    // We can keep it if other parts of the app use it, but HotKeyManager handles the activation.
    func matches(_ event: NSEvent) -> Bool {
        // ... (implementation kept if needed, but HotKeyManager is primary now)
        return false 
    }
    
    private func updateHotKey() {
        if let shortcut = shortcut {
            logger.info("Registering custom shortcut: \(shortcut.keyCode)")
            HotKeyManager.shared.registerHotkey(keyCode: shortcut.keyCode, modifiers: Int(shortcut.modifiers))
        } else {
            logger.info("Registering default shortcut")
            HotKeyManager.shared.registerDefault()
        }
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
