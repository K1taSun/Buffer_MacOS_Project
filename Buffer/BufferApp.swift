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
    private var monitor: Any?
    
    func applicationDidFinishLaunching(_ notification: Notification) {
        setupGlobalMonitor()
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
