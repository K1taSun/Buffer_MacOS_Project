import SwiftUI
import AppKit

class WindowManager: ObservableObject {
    static let shared = WindowManager()
    private var window: NSWindow?
    private let windowSize = NSSize(width: 450, height: 600)
    private let animationDuration: TimeInterval = 0.25
    
    private init() {}
    
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
    }
    
    private func setupContentView(for window: NSWindow) {
        let contentView = ClipboardView()
            .environmentObject(ClipboardManager.shared)
        window.contentView = NSHostingView(rootView: contentView)
    }
    
    private func positionWindow() {
        guard let window = window,
              let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame
        
        // Position window in the center of the screen
        let x = screenFrame.midX - windowFrame.width / 2
        let y = screenFrame.midY - windowFrame.height / 2
        
        // Ensure window is fully visible on screen
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