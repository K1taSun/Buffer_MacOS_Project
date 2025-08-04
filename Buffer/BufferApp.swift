import SwiftUI
import AppKit

@main
struct BufferApp: App {
    @StateObject private var clipboardManager = ClipboardManager.shared
    @NSApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    var body: some Scene {
        MenuBarExtra("Buffer", systemImage: "doc.on.clipboard") {
            ClipboardView()
                .environmentObject(clipboardManager)
        }
        .menuBarExtraStyle(.window)
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        // Request accessibility permissions for global keyboard shortcuts
        requestAccessibilityPermissions()
        
        setupGlobalMonitor()
        setupLocalMonitor()
        
        // Set up the app to run in the background
        NSApp.setActivationPolicy(.accessory)
    }
    
    private func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !accessEnabled {
            print("Accessibility permissions are required for global keyboard shortcuts")
        }
    }
    
    private func setupGlobalMonitor() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            _ = self?.handleKeyEvent(event)
        }
    }
    
    private func setupLocalMonitor() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if self?.handleKeyEvent(event) == true {
                return nil
            }
            return event
        }
    }
    
    private func handleKeyEvent(_ event: NSEvent) -> Bool {
        // Check for Cmd+` shortcut
        if event.modifierFlags.contains(.command) && event.characters == "`" {
            DispatchQueue.main.async {
                WindowManager.shared.toggleWindow()
            }
            return true
        }
        
        // Check for Cmd+Shift+V shortcut as alternative
        if event.modifierFlags.contains([.command, .shift]) && event.characters == "v" {
            DispatchQueue.main.async {
                WindowManager.shared.toggleWindow()
            }
            return true
        }
        
        return false
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        cleanupMonitors()
    }
    
    private func cleanupMonitors() {
        if let globalMonitor = globalMonitor {
            NSEvent.removeMonitor(globalMonitor)
            self.globalMonitor = nil
        }
        
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }
    
    deinit {
        cleanupMonitors()
    }
}
