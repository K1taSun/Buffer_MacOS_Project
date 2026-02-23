import SwiftUI

struct SettingsView: View {
    @Binding var isPresented: Bool
    @StateObject private var shortcutManager = ShortcutManager.shared
    @EnvironmentObject private var languageManager: LanguageManager
    
    var body: some View {
        VStack(spacing: 20) {
            Text(languageManager.localized("settings.title"))
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 10) {
                // Sekcja Wyboru Języka
                HStack {
                    Text(languageManager.localized("settings.language"))
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    Spacer()
                    
                    Picker("", selection: $languageManager.currentLanguage) {
                        ForEach(AppLanguage.allCases) { language in
                            Text(language.displayName).tag(language)
                        }
                    }
                    .frame(width: 120)
                    .pickerStyle(MenuPickerStyle())
                }
                
                Divider().padding(.vertical, 4)
                
                // Sekcja Skrótów Klawiszowych
                Text(languageManager.localized("settings.globalShortcut"))
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Button(action: {
                        toggleRecording()
                    }) {
                        HStack {
                            if shortcutManager.isRecording {
                                Image(systemName: "record.circle")
                                    .foregroundColor(.red)
                                Text(languageManager.localized("settings.recording"))
                            } else {
                                Image(systemName: "keyboard")
                                Text(shortcutManager.shortcut?.displayString ?? languageManager.localized("settings.defaultShortcut"))
                            }
                        }
                        .frame(minWidth: 150)
                        .padding(8)
                        .background(Color(NSColor.controlBackgroundColor))
                        .cornerRadius(6)
                        .overlay(
                            RoundedRectangle(cornerRadius: 6)
                                .stroke(shortcutManager.isRecording ? Color.blue : Color.secondary.opacity(0.3), lineWidth: 1)
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
            
            HStack {
                Spacer()
                Button(languageManager.localized("settings.done")) {
                    if shortcutManager.isRecording {
                        shortcutManager.stopRecording()
                    }
                    isPresented = false
                }
                .keyboardShortcut(.defaultAction)
            }
        }
        .padding()
        .frame(width: 450, height: 600) // Match parent size for seamless overlay
        .background(Color(NSColor.windowBackgroundColor))
        .contentShape(Rectangle())
        .onTapGesture {
            // Consume clicks to prevent window dismissal
        }
    }
    
    private func toggleRecording() {
        if shortcutManager.isRecording {
            shortcutManager.stopRecording()
        } else {
            shortcutManager.startRecording()
        }
    }
}
