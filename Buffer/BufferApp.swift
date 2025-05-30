//
//  BufferApp.swift
//  Buffer
//
//  Created by Nikita Parkovskyi on 26/05/2025.
//

import SwiftUI
import AppKit

@main
struct BufferApp: App {
    @StateObject private var clipboardManager = ClipboardManager()
    
    var body: some Scene {
        MenuBarExtra("Buffer", systemImage: "doc.on.clipboard") {
            ClipboardView()
                .environmentObject(clipboardManager)
        }
        .menuBarExtraStyle(.window)
        Settings {
            EmptyView()
        }
    }
}

class AppDelegate: NSObject, NSApplicationDelegate {
    var statusItem: NSStatusItem?
    var monitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupStatusItem()
        setupGlobalMonitor()
    }
    
    private func setupStatusItem() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        statusItem?.button?.image = NSImage(systemSymbolName: "doc.on.clipboard", accessibilityDescription: "Buffer")
    }
    
    private func setupGlobalMonitor() {
        monitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) && event.characters == "`" {
                DispatchQueue.main.async {
                    WindowManager.shared.toggleWindow()
                }
            }
        }
    }
    
    func applicationWillTerminate(_ notification: Notification) {
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
        }
    }
}
