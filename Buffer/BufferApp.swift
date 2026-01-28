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

import os

class AppDelegate: NSObject, NSApplicationDelegate {
    private var globalMonitor: Any?
    private var localMonitor: Any?
    private let logger = Logger(subsystem: "com.buffer.macos", category: "Events")
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("Application did finish launching")
        // Najpierw ustaw politykę aktywacji
        NSApp.setActivationPolicy(.accessory)
        
        // Następnie skonfiguruj monitory skrótów
        setupGlobalMonitor()
        setupLocalMonitor()
        
        // Na końcu poproś o uprawnienia i aktywuj aplikację
        requestAccessibilityPermissions()
        
        // Aktywacja aplikacji natychmiast po starcie - gotowa do odbierania skrótów
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    private func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !accessEnabled {
            logger.error("Accessibility permissions NOT granted")
            
            DispatchQueue.main.async {
                let alert = NSAlert()
                alert.messageText = "Accessibility Permissions Required"
                alert.informativeText = "Buffer needs accessibility permissions to detect global keyboard shortcuts.\n\nPlease grant access in System Settings > Privacy & Security > Accessibility."
                alert.alertStyle = .warning
                alert.addButton(withTitle: "Open Settings")
                alert.addButton(withTitle: "Cancel")
                
                let response = alert.runModal()
                if response == .alertFirstButtonReturn {
                    let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility")!
                    NSWorkspace.shared.open(url)
                }
            }
        } else {
            logger.info("Accessibility permissions granted")
        }
    }
    
    private func setupGlobalMonitor() {
        logger.info("Setting up global monitor")
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.logger.debug("Global event received: \(event.keyCode)")
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
        if ShortcutManager.shared.matches(event) {
            logger.notice("Shortcut matched! Toggling window.")
            // Bezpośrednie wywołanie na głównym wątku - już jesteśmy w monitorze
            WindowManager.shared.toggleWindow()
            return true
        } else {
            logger.debug("No match for event")
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
