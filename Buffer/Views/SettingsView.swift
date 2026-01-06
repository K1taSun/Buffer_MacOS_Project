import SwiftUI

struct SettingsView: View {
    @Environment(\.dismiss) var dismiss
    @StateObject private var shortcutManager = ShortcutManager.shared
    @State private var isRecording = false
    @State private var monitor: Any?
    
    var body: some View {
        VStack(spacing: 20) {
            Text("Settings")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 10) {
                Text("Global Shortcut")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Button(action: {
                        toggleRecording()
                    }) {
                        HStack {
                            if isRecording {
                                Image(systemName: "record.circle")
                                    .foregroundColor(.red)
                                Text("Recording... Press keys")
                            } else {
                                Image(systemName: "keyboard")
                                Text(shortcutManager.shortcut?.displayString ?? "⌘⇧V (Default)")
                            }
                        }
                        .frame(minWidth: 150)
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(isRecording ? Color.blue : Color.secondary.opacity(0.3), lineWidth: 1)
                        )
                    }
                    .buttonStyle(.plain)
                    
                    if shortcutManager.shortcut != nil {
                        Button(action: {
                            shortcutManager.shortcut = nil
                        }) {
                            Image(systemName: "arrow.counterclockwise")
                                .help("Reset to default")
                        }
                    }
                }
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))
            .cornerRadius(8)
            
            Spacer()
            
            Button("Done") {
                stopRecording()
                dismiss()
            }
        }
        .padding()
        .frame(width: 300, height: 200)
    }
    
    private func toggleRecording() {
        if isRecording {
            stopRecording()
        } else {
            startRecording()
        }
    }
    
    private func startRecording() {
        isRecording = true
        monitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Cancel on Escape
            if event.keyCode == 53 {
                stopRecording()
                return nil
            }
            
            shortcutManager.setShortcut(event: event)
            stopRecording()
            return nil 
        }
    }
    
    private func stopRecording() {
        isRecording = false
        if let monitor = monitor {
            NSEvent.removeMonitor(monitor)
            self.monitor = nil
        }
    }
}
