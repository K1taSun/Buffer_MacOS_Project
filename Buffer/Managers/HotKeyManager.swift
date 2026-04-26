import Cocoa
import Carbon

class HotKeyManager {
    static let shared = HotKeyManager()
    
    private var hotKeyRef: EventHotKeyRef?
    private var eventHandler: EventHandlerRef?
    

    
    init() {
        installEventHandler()
    }
    
    func registerHotkey(keyCode: Int, modifiers: Int) {
        unregisterHotkey()
        
        var gID = EventHotKeyID()
        gID.signature = OSType("hvcb".asUInt32) // "hvcb" = Heavy Clipboard (random signature)
        gID.id = 1
        
        var registerModifiers: UInt32 = 0
        
        // Convert NSEvent modifiers to Carbon modifiers
        let mods = UInt(modifiers)
        if (mods & NSEvent.ModifierFlags.command.rawValue) != 0 { registerModifiers |= UInt32(cmdKey) }
        if (mods & NSEvent.ModifierFlags.shift.rawValue) != 0 { registerModifiers |= UInt32(shiftKey) }
        if (mods & NSEvent.ModifierFlags.option.rawValue) != 0 { registerModifiers |= UInt32(optionKey) }
        if (mods & NSEvent.ModifierFlags.control.rawValue) != 0 { registerModifiers |= UInt32(controlKey) }
        
        // Fallback for direct Carbon flags (e.g. default Cmd+Shift)
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
            DispatchQueue.main.async {
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
    
    func registerDefault() {
        unregisterHotkey()
        
        var gID = EventHotKeyID()
        gID.signature = OSType("hvcb".asUInt32)
        gID.id = 1
        
        let status = RegisterEventHotKey(UInt32(9),
                                         UInt32(cmdKey | shiftKey),
                                         gID,
                                         GetApplicationEventTarget(),
                                         0,
                                         &hotKeyRef)
        
        if status != noErr {
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
