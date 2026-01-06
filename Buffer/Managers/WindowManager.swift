import SwiftUI
import AppKit

class WindowManager: NSObject, ObservableObject {
    static let shared = WindowManager()
    private var window: NSWindow?
    private let windowSize = NSSize(width: 320, height: 480)
    private let animationDuration: TimeInterval = 0.25
    
    private override init() {}
    
    func toggleWindow() {
        if window == nil {
            createWindow()
        } else {
            window?.isVisible == true ? hideWindow() : showWindow()
        }
    }
    
    func showWindow() {
        if window == nil {
            createWindow()
        } else {
            guard let window = window else { return }
            
            window.alphaValue = 0
            window.makeKeyAndOrderFront(nil)
            NSApp.activate(ignoringOtherApps: true)
            
            NSAnimationContext.runAnimationGroup { context in
                context.duration = animationDuration
                context.timingFunction = CAMediaTimingFunction(name: .easeOut)
                window.animator().alphaValue = 1
            }
        }
    }
    
    func hideWindow() {
        guard let window = window else { return }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = animationDuration
            context.timingFunction = CAMediaTimingFunction(name: .easeIn)
            window.animator().alphaValue = 0
        } completionHandler: {
            window.orderOut(nil)
        }
    }
    
    private func createWindow() {
        let window = NSWindow(
            contentRect: NSRect(origin: .zero, size: windowSize),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        configureWindow(window)
        setupContentView(for: window)
        self.window = window
        positionWindow()
        showWindow()
    }
    
    private func configureWindow(_ window: NSWindow) {
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .managed]
        window.animationBehavior = .documentWindow
        window.isMovableByWindowBackground = true
        window.backgroundColor = NSColor.windowBackgroundColor
        
        // Set window appearance
        if #available(macOS 11.0, *) {
            window.toolbarStyle = .unified
        }
        
        window.delegate = self
    }
    
    private func setupContentView(for window: NSWindow) {
        let contentView = ClipboardView()
            .environmentObject(ClipboardManager.shared)
        window.contentView = NSHostingView(rootView: contentView)
    }
    
    private func positionWindow() {
        guard let window = window else { return }
        
        let screen = NSScreen.main ?? NSScreen.screens.first
        guard let targetScreen = screen else { return }
        
        let screenFrame = targetScreen.visibleFrame
        let windowFrame = window.frame
        
        let x = screenFrame.midX - windowFrame.width / 2
        let y = screenFrame.midY - windowFrame.height / 2
        
        let finalX = max(screenFrame.minX, min(x, screenFrame.maxX - windowFrame.width))
        let finalY = max(screenFrame.minY, min(y, screenFrame.maxY - windowFrame.height))
        
        window.setFrame(NSRect(x: finalX, y: finalY, width: windowFrame.width, height: windowFrame.height), display: true)
    }
    
    func repositionWindow() {
        guard window != nil else { return }
        positionWindow()
    }
    
    func closeWindow() {
        guard let window = window else { return }
        window.close()
        self.window = nil
    }
    
    func isWindowVisible() -> Bool {
        return window?.isVisible == true
    }
}

// MARK: - NSWindowDelegate
extension WindowManager: NSWindowDelegate {
    func windowWillClose(_ notification: Notification) {
        if let closingWindow = notification.object as? NSWindow, closingWindow === window {
            window = nil
        }
    }
    
    func windowDidResignKey(_ notification: Notification) {
        // hideWindow()
    }
} 