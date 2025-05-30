import SwiftUI
import AppKit

class WindowManager: ObservableObject {
    static let shared = WindowManager()
    private var window: NSWindow?
    
    func toggleWindow() {
        if window == nil {
            createWindow()
        } else {
            if window?.isVisible == true {
                hideWindow()
            } else {
                showWindow()
            }
        }
    }
    
    private func createWindow() {
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 500),
            styleMask: [.titled, .closable, .miniaturizable, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        
        window.titlebarAppearsTransparent = true
        window.titleVisibility = .hidden
        window.isReleasedWhenClosed = false
        window.level = .floating
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        window.animationBehavior = .documentWindow
        
        let contentView = ClipboardView()
            .environmentObject(ClipboardManager.shared)
        
        window.contentView = NSHostingView(rootView: contentView)
        self.window = window
        positionWindow()
        showWindow()
    }
    
    private func showWindow() {
        guard let window = window else { return }
        
        // Set initial position and alpha
        window.alphaValue = 0
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        
        // Animate window appearance
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            window.animator().alphaValue = 1
        }
    }
    
    private func hideWindow() {
        guard let window = window else { return }
        
        // Animate window disappearance
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.2
            window.animator().alphaValue = 0
        } completionHandler: {
            window.orderOut(nil)
        }
    }
    
    private func positionWindow() {
        guard let window = window else { return }
        
        if let screen = NSScreen.main {
            let screenFrame = screen.visibleFrame
            let windowFrame = window.frame
            
            // Position window in the center of the screen
            let x = screenFrame.midX - windowFrame.width / 2
            let y = screenFrame.midY - windowFrame.height / 2
            
            window.setFrame(NSRect(x: x, y: y, width: windowFrame.width, height: windowFrame.height), display: true)
        }
    }
} 