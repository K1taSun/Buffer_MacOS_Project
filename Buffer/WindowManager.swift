import SwiftUI
import AppKit

class WindowManager: ObservableObject {
    static let shared = WindowManager()
    private var window: NSWindow?
    private let windowSize = NSSize(width: 400, height: 500)
    private let animationDuration: TimeInterval = 0.2
    
    private init() {}
    
    func toggleWindow() {
        if window == nil {
            createWindow()
        } else {
            window?.isVisible == true ? hideWindow() : showWindow()
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
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.animationBehavior = .documentWindow
    }
    
    private func setupContentView(for window: NSWindow) {
        let contentView = ClipboardView()
            .environmentObject(ClipboardManager.shared)
        window.contentView = NSHostingView(rootView: contentView)
    }
    
    private func showWindow() {
        guard let window = window else { return }
        
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = animationDuration
            window.animator().alphaValue = 1
        }
    }
    
    private func hideWindow() {
        guard let window = window else { return }
        
        NSAnimationContext.runAnimationGroup { context in
            context.duration = animationDuration
            window.animator().alphaValue = 0
        } completionHandler: {
            window.orderOut(nil)
        }
    }
    
    private func positionWindow() {
        guard let window = window,
              let screen = NSScreen.main else { return }
        
        let screenFrame = screen.visibleFrame
        let windowFrame = window.frame
        
        let x = screenFrame.midX - windowFrame.width / 2
        let y = screenFrame.midY - windowFrame.height / 2
        
        window.setFrame(NSRect(x: x, y: y, width: windowFrame.width, height: windowFrame.height), display: true)
    }
} 