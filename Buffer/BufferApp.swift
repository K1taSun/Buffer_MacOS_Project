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
        if ShortcutManager.shared.matches(event) {
            // Bezpośrednie wywołanie na głównym wątku - już jesteśmy w monitorze
            WindowManager.shared.toggleWindow()
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
