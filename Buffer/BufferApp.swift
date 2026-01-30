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
    private var localMonitor: Any?
    private let logger = Logger(subsystem: "com.buffer.macos", category: "Events")
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        logger.info("Application did finish launching")
        // Najpierw ustaw politykę aktywacji
        NSApp.setActivationPolicy(.accessory)
        
        // Inicjalizacja managera skrótów (Carbon) - to zarejestruje domyślny skrót lub zapisany
        _ = ShortcutManager.shared
        
        // Następnie skonfiguruj lokalny monitor (opcjonalnie, do innych celów, np. ESC w oknie)
        setupLocalMonitor()
        
        // Na końcu poproś o uprawnienia i aktywuj aplikację
        // Uprawnienia Accessibility nadal mogą być przydatne do wklejania, ale nie są krytyczne dla samego skrótu otwieranai okna
        requestAccessibilityPermissions()
        
        // Aktywacja aplikacji natychmiast po starcie
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            NSApp.activate(ignoringOtherApps: true)
        }
    }
    
    private func requestAccessibilityPermissions() {
        let options = [kAXTrustedCheckOptionPrompt.takeUnretainedValue() as String: true]
        let accessEnabled = AXIsProcessTrustedWithOptions(options as CFDictionary)
        
        if !accessEnabled {
            logger.warning("Accessibility permissions NOT granted - specific features like pasting might be limited, but global shortcut will work.")
        } else {
            logger.info("Accessibility permissions granted")
        }
    }
    
    private func setupLocalMonitor() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Tutaj możemy obsłużyć specyficzne klawisze gdy aplikacja jest aktywna
            // Na przykład wciśnięcie ESC żeby zamknąć okno, jeśli nie jest to obsłużone w SwiftUI
            // Ale na razie zostawmy standardowe zachowanie
            return event
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        if let localMonitor = localMonitor {
            NSEvent.removeMonitor(localMonitor)
            self.localMonitor = nil
        }
    }
}
