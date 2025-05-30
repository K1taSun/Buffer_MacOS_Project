import SwiftUI

struct ClipboardView: View {
    @EnvironmentObject private var clipboardManager: ClipboardManager
    @State private var searchText = ""
    @State private var isAppearing = false
    
    private var filteredItems: [ClipboardItem] {
        searchText.isEmpty ? clipboardManager.items : clipboardManager.items.filter { 
            $0.content.localizedCaseInsensitiveContains(searchText) 
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            contentView
            footerView
        }
        .frame(width: 400, height: 500)
        .opacity(isAppearing ? 1 : 0)
        .scaleEffect(isAppearing ? 1 : 0.95)
        .onAppear(perform: setupAppearance)
    }
    
    private var headerView: some View {
        HStack {
            Text("Clipboard History")
                .font(.headline)
            Spacer()
            TextField("Search", text: $searchText)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 200)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var contentView: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(filteredItems) { item in
                    ClipboardItemView(item: item)
                        .contextMenu {
                            Button("Copy") { clipboardManager.copyItem(item) }
                            Button(item.isPinned ? "Unpin" : "Pin") { clipboardManager.togglePin(item) }
                            Button("Delete") { clipboardManager.removeItem(item) }
                        }
                        .onTapGesture { clipboardManager.copyItem(item) }
                }
            }
        }
    }
    
    private var footerView: some View {
        HStack {
            Spacer()
            Button("Clear All") { clipboardManager.clearAll() }
                .buttonStyle(.plain)
                .foregroundColor(.blue)
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func setupAppearance() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isAppearing = true
        }
        
        NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.modifierFlags.contains(.command) && event.characters == "`" {
                WindowManager.shared.toggleWindow()
                return nil
            }
            if event.keyCode == 53 { // Escape key
                WindowManager.shared.toggleWindow()
                return nil
            }
            return event
        }
    }
}

struct GlowEffect: ViewModifier {
    let isHovered: Bool
    let isSelected: Bool
    
    func body(content: Content) -> some View {
        content
            .overlay(outerGlow)
            .overlay(innerGlow)
            .overlay(selectionBorder)
    }
    
    private var outerGlow: some View {
        RoundedRectangle(cornerRadius: 6)
            .stroke(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue.opacity(isHovered ? 0.9 : 0),
                        Color.blue.opacity(isHovered ? 0.6 : 0),
                        Color.blue.opacity(isHovered ? 0.9 : 0)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: isHovered ? 3 : 0
            )
            .blur(radius: isHovered ? 3 : 0)
    }
    
    private var innerGlow: some View {
        RoundedRectangle(cornerRadius: 6)
            .stroke(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.white.opacity(isHovered ? 0.8 : 0),
                        Color.blue.opacity(isHovered ? 0.6 : 0),
                        Color.white.opacity(isHovered ? 0.8 : 0)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: isHovered ? 1 : 0
            )
            .blur(radius: isHovered ? 1 : 0)
    }
    
    private var selectionBorder: some View {
        RoundedRectangle(cornerRadius: 6)
            .stroke(
                LinearGradient(
                    gradient: Gradient(colors: [
                        Color.blue.opacity(isSelected ? 0.8 : 0),
                        Color.blue.opacity(isSelected ? 0.5 : 0),
                        Color.blue.opacity(isSelected ? 0.8 : 0)
                    ]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                lineWidth: isSelected ? 2 : 0
            )
            .shadow(color: .blue.opacity(isSelected ? 0.5 : 0), radius: isSelected ? 4 : 0)
            .blur(radius: isSelected ? 1 : 0)
    }
}

struct ClipboardItemView: View {
    let item: ClipboardItem
    @EnvironmentObject private var clipboardManager: ClipboardManager
    @State private var isHovered = false
    @State private var isSelected = false
    
    var body: some View {
        HStack(spacing: 8) {
            itemIcon
            itemContent
            pinButton
        }
        .padding(.vertical, 8)
        .padding(.horizontal, 12)
        .background(itemBackground)
        .modifier(GlowEffect(isHovered: isHovered, isSelected: isSelected))
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .shadow(color: .black.opacity(isSelected ? 0.1 : 0), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .onHover { hovering in
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                isHovered = hovering
            }
        }
        .onTapGesture(perform: handleTap)
    }
    
    private var itemIcon: some View {
        Group {
            if item.type == .image, let data = item.data, let nsImage = NSImage(data: data) {
                Image(nsImage: nsImage)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 40, height: 40)
                    .cornerRadius(4)
            } else {
                Image(systemName: item.type.icon)
                    .foregroundColor(.secondary)
                    .frame(width: 20)
            }
        }
    }
    
    private var itemContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            if item.type == .image {
                Text("Image")
                    .lineLimit(1)
                    .font(.system(size: 13))
            } else {
                Text(item.content)
                    .lineLimit(2)
                    .font(.system(size: 13))
            }
            
            HStack {
                Text(item.type.rawValue.capitalized)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Spacer()
                
                Text(item.timestamp, style: .time)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }
    
    private var pinButton: some View {
        Button(action: {
            withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                clipboardManager.togglePin(item)
            }
        }) {
            Image(systemName: item.isPinned ? "pin.fill" : "pin")
                .foregroundColor(item.isPinned ? .blue : .secondary)
                .scaleEffect(isHovered ? 1.1 : 1.0)
        }
        .buttonStyle(.plain)
    }
    
    private var itemBackground: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(NSColor.controlBackgroundColor))
            .shadow(color: .black.opacity(isHovered ? 0.1 : 0), radius: isHovered ? 4 : 0, x: 0, y: 2)
    }
    
    private func handleTap() {
        withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
            isSelected = true
            clipboardManager.copyItem(item)
            
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                withAnimation(.spring(response: 0.2, dampingFraction: 0.6)) {
                    isSelected = false
                }
            }
        }
    }
} 
