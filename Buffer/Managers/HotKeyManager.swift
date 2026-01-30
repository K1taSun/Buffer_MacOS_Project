import Cocoa
import Carbon

class HotKeyManager {
    static let shared = HotKeyManager()
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    
    // Default: Cmd + Shift + V
    // V = 9 (kVK_ANSI_V)
    // Cmd = cmdKey
    // Shift = shiftKey
    private let defaultKeyCode: Int = 9
    private let defaultModifiers: Int = cmdKey | shiftKey
    
    init() {
        installEventHandler()
    }
    
    func registerHotkey(keyCode: Int, modifiers: Int) {
        unregisterHotkey()
        
        var gID = EventHotKeyID()
        gID.signature = OSType("hvcb".asUInt32) // "hvcb" = Heavy Clipboard (random signature)
        gID.id = 1
        
        var registerModifiers: UInt32 = 0
        
        // Convert AppKit/NSEvent modifiers to Carbon modifiers
        // Note: The incoming modifiers are likely Carbon format if coming from NSEvent.modifierFlags.rawValue conversion
        // But let's check inputs carefully.
        // For simplicity, we assume we receive Carbon-compatible modifier flags or we map them.
        
        // However, ShortcutManager stores NSEvent.ModifierFlags.rawValue.
        // We need to convert NSEvent modifiers to Carbon.
        
        // Mapping:
        // NSEvent.ModifierFlags.command -> cmdKey
        // NSEvent.ModifierFlags.shift -> shiftKey
        // NSEvent.ModifierFlags.option -> optionKey
        // NSEvent.ModifierFlags.control -> controlKey
        
        // Assuming 'modifiers' passed here handles this or we map it.
        // Let's implement robust mapping below based on standard Carbon constants.
        
        let mods = UInt(modifiers)
        if (mods & NSEvent.ModifierFlags.command.rawValue) != 0 { registerModifiers |= UInt32(cmdKey) }
        if (mods & NSEvent.ModifierFlags.shift.rawValue) != 0 { registerModifiers |= UInt32(shiftKey) }
        if (mods & NSEvent.ModifierFlags.option.rawValue) != 0 { registerModifiers |= UInt32(optionKey) }
        if (mods & NSEvent.ModifierFlags.control.rawValue) != 0 { registerModifiers |= UInt32(controlKey) } 
        // Also support passing direct Carbon flags if needed, but let's stick to NSEvent mapping for consistency with ShortcutManager
        
        // Fallback for default shortcut logic if raw Carbon flags are passed (like defaultModifiers above)
        if modifiers == (cmdKey | shiftKey) {
             registerModifiers = UInt32(cmdKey | shiftKey)
        }
        
        let status = RegisterEventHotKey(UInt32(keyCode),
                                         registerModifiers,
                                         gID,
                                         GetApplicationEventTarget(),
                                         0,
                                         &hotKeyRef)
        
        if status != noErr {
            print("Failed to register hotkey: \(status)")
        } else {
            print("Registered hotkey: KeyCode \(keyCode), Mods \(modifiers)")
        }
    }
    
    func unregisterHotkey() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
    }
    
    private func installEventHandler() {
        var eventType = EventTypeSpec()
        eventType.eventClass = OSType(kEventClassKeyboard)
        eventType.eventKind = UInt32(kEventHotKeyPressed)
        
        let handler: EventHandlerUPP = { _, _, _ in
            // Hotkey match!
            DispatchQueue.main.async {
                print("HotKey pressed! Toggling window...")
                WindowManager.shared.toggleWindow()
            }
            return noErr
        }
        
        InstallEventHandler(GetApplicationEventTarget(),
                            handler,
                            1,
                            &eventType,
                            nil,
                            &eventHandler)
    }
    
    // Helper to register default if no custom
    func registerDefault() {
        // Carbon modifier keys
        // cmdKey = 256 (bit 8)
        // shiftKey = 512 (bit 9)
        // Register default Cmd+Shift+V
        // Direct carbon usage
        unregisterHotkey()
        
        var gID = EventHotKeyID()
        gID.signature = OSType("hvcb".asUInt32)
        gID.id = 1
        
        // kVK_ANSI_V = 9
        let status = RegisterEventHotKey(UInt32(9),
                                         UInt32(cmdKey | shiftKey),
                                         gID,
                                         GetApplicationEventTarget(),
                                         0,
                                         &hotKeyRef)
        
        if status == noErr {
            print("Registered Default Hotkey: Cmd+Shift+V")
        } else {
             print("Failed to register default hotkey: \(status)")
        }
    }
}

// Helper extension for OSType
extension String {
    var asUInt32: UInt32 {
        var result: UInt32 = 0
        for char in self.utf8 {
            result = (result << 8) | UInt32(char)
        }
        return result
    }
}
