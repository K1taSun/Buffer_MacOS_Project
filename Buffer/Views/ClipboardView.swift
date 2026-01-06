import SwiftUI

struct ClipboardView: View {
    @EnvironmentObject private var clipboardManager: ClipboardManager
    @State private var searchText = ""
    @State private var isAppearing = false
    @State private var selectedFilter: ClipboardFilter = .all
    @State private var previewedImage: ImagePreviewData? = nil
    @State private var showCopyFeedback = false
    @State private var showSettings = false
    
    private var filteredItems: [ClipboardItem] {
        let items = clipboardManager.items
        
        // Apply search filter
        let searchFiltered = searchText.isEmpty ? items : items.filter { 
            $0.content.localizedCaseInsensitiveContains(searchText) 
        }
        
        // Apply type filter
        switch selectedFilter {
        case .all:
            return searchFiltered
        case .text:
            return searchFiltered.filter { $0.type == .text }
        case .images:
            return searchFiltered.filter { $0.type == .image }
        case .files:
            return searchFiltered.filter { $0.type == .file }
        case .urls:
            return searchFiltered.filter { $0.type == .url }
        case .pinned:
            return searchFiltered.filter { $0.isPinned }
        }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            headerView
            filterView
            contentView
            footerView
        }
        .frame(width: 450, height: 600)
        .opacity(isAppearing ? 1 : 0)
        .scaleEffect(isAppearing ? 1 : 0.95)
        .onAppear(perform: setupAppearance)
        .sheet(item: $previewedImage) { preview in
            ImagePreviewSheet(image: preview.image)
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .overlay(
            Group {
                if showCopyFeedback {
                    VStack {
                        Spacer()
                        HStack {
                            Spacer()
                            Text("Copied!")
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.green)
                                )
                                .shadow(radius: 4)
                            Spacer()
                        }
                        .padding(.bottom, 20)
                    }
                    .transition(.move(edge: .bottom).combined(with: .opacity))
                    .zIndex(1000)
                }
            }
        )
    }
    
    private var headerView: some View {
        HStack {
            Text("Clipboard History")
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            HStack(spacing: 8) {
                TextField("Search", text: $searchText)
                    .textFieldStyle(RoundedBorderTextFieldStyle())
                    .frame(width: 140)
                
                Button(action: {
                    searchText = ""
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .opacity(searchText.isEmpty ? 0 : 1)
                
                Button(action: {
                    showSettings = true
                }) {
                    Image(systemName: "gearshape")
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
                .help("Settings")
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private var filterView: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(ClipboardFilter.allCases, id: \.self) { filter in
                    FilterButton(
                        title: filter.title,
                        isSelected: selectedFilter == filter,
                        action: { selectedFilter = filter }
                    )
                }
            }
            .padding(.horizontal)
        }
        .padding(.vertical, 8)
        .background(Color(NSColor.controlBackgroundColor))
    }
    
    private var contentView: some View {
        Group {
            if filteredItems.isEmpty {
                emptyStateView
            } else {
                ScrollView {
                    LazyVStack(spacing: 4) {
                        ForEach(filteredItems) { item in
                            ClipboardItemView(item: item, onImageTap: { nsImage in
                                previewedImage = ImagePreviewData(image: nsImage)
                            })
                                .contextMenu {
                                    Button("Copy") { 
                                        clipboardManager.copyItem(item)
                                        triggerCopyFeedback()
                                    }
                                    Button(item.isPinned ? "Unpin" : "Pin") { 
                                        clipboardManager.togglePin(item) 
                                    }
                                    Divider()
                                    Button("Delete") { clipboardManager.removeItem(item) }
                                }
                                .onTapGesture { 
                                    clipboardManager.copyItem(item)
                                    triggerCopyFeedback()
                                }
                                .onDrag {
                                    item.itemProvider
                                }
                        }
                    }
                    .padding(.vertical, 8)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "doc.on.clipboard")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text(emptyStateMessage)
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text(emptyStateSubtitle)
                .font(.caption)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    private var emptyStateMessage: String {
        if !searchText.isEmpty {
            return "No items found"
        }
        switch selectedFilter {
        case .all:
            return "No clipboard items"
        case .text:
            return "No text items"
        case .images:
            return "No images"
        case .files:
            return "No files"
        case .urls:
            return "No URLs"
        case .pinned:
            return "No pinned items"
        }
    }
    
    private var emptyStateSubtitle: String {
        if !searchText.isEmpty {
            return "Try adjusting your search terms"
        }
        switch selectedFilter {
        case .all:
            return "Copy something to get started"
        case .text:
            return "Copy some text to see it here"
        case .images:
            return "Copy an image to see it here"
        case .files:
            return "Copy a file to see it here"
        case .urls:
            return "Copy a URL to see it here"
        case .pinned:
            return "Pin items to keep them here"
        }
    }
    
    private var footerView: some View {
        HStack {
            Text("\(filteredItems.count) items")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack(spacing: 12) {
                Button("Clear Unpinned") { 
                    clipboardManager.clearUnpinned() 
                }
                .padding(10)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
                .foregroundColor(.orange)

                Button("Clear All") { 
                    clipboardManager.clearAll() 
                }
                .padding(10)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
                .foregroundColor(.red)
            }
        }
        .padding()
        .background(Color(NSColor.windowBackgroundColor))
    }
    
    private func setupAppearance() {
        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
            isAppearing = true
        }
    }
    
    private func triggerCopyFeedback() {
        withAnimation(.easeInOut(duration: 0.2)) {
            showCopyFeedback = true
        }
        
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
            withAnimation(.easeInOut(duration: 0.2)) {
                showCopyFeedback = false
            }
        }
    }
}

struct FilterButton: View {
    let title: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            Text(title)
                .font(.footnote)
                .fontWeight(.medium)
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(
                    RoundedRectangle(cornerRadius: 14)
                        .fill(isSelected ? Color.blue : Color.clear)
                )
                .foregroundColor(isSelected ? .white : .primary)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
                )
        }
        .contentShape(Rectangle())
        .buttonStyle(.plain)
    }
}

enum ClipboardFilter: CaseIterable {
    case all, text, images, files, urls, pinned
    
    var title: String {
        switch self {
        case .all: return "All"
        case .text: return "Text"
        case .images: return "Images"
        case .files: return "Files"
        case .urls: return "URLs"
        case .pinned: return "Pinned"
        }
    }
}

struct ClipboardItemView: View {
    let item: ClipboardItem
    @EnvironmentObject private var clipboardManager: ClipboardManager
    @State private var isHovered = false
    @State private var isSelected = false
    var onImageTap: ((NSImage) -> Void)? = nil
    
    var body: some View {
        HStack(spacing: 12) {
            itemIcon
            itemContent
            pinButton
        }
        .padding(.vertical, 10)
        .padding(.horizontal, 16)
        .background(itemBackground)
        .contentShape(Rectangle())
        .modifier(GlowEffect(isHovered: isHovered, isSelected: isSelected))
        .scaleEffect(isSelected ? 1.02 : 1.0)
        .shadow(color: .black.opacity(isSelected ? 0.1 : 0), radius: 4, x: 0, y: 2)
        .padding(.horizontal, 12)
        .padding(.vertical, 2)
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
                    .frame(width: 44, height: 44)
                    .cornerRadius(6)
                    .shadow(color: .black.opacity(0.1), radius: 2, x: 0, y: 1)
                    .onTapGesture {
                        onImageTap?(nsImage)
                    }
            } else if item.type == .file, let url = URL(string: item.content), !url.path.isEmpty {
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                Image(nsImage: icon)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 44, height: 44)
            } else {
                Image(systemName: item.type.icon)
                    .font(.system(size: 20))
                    .foregroundColor(.secondary)
                    .frame(width: 44, height: 44)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(6)
            }
        }
    }
    
    private var itemContent: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(item.displayName)
                .lineLimit(3)
                .font(.system(size: 14))
                .foregroundColor(.primary)
            
            HStack {
                HStack(spacing: 4) {
                    Text(item.type.rawValue.capitalized)
                    if let fileExt = item.fileExtension {
                        Text("(\(fileExt))")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(
                        RoundedRectangle(cornerRadius: 4)
                            .fill(Color.secondary.opacity(0.1))
                    )
                
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
                .font(.system(size: 14))
                .padding(8)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
    
    private var itemBackground: some View {
        RoundedRectangle(cornerRadius: 8)
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
        RoundedRectangle(cornerRadius: 8)
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
        RoundedRectangle(cornerRadius: 8)
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
        RoundedRectangle(cornerRadius: 8)
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

struct ImagePreviewData: Identifiable {
    let id = UUID()
    let image: NSImage
}

struct ImagePreviewSheet: View {
    let image: NSImage
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        VStack {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 500, maxHeight: 500)
                .padding()
            
            Button("Close") {
                dismiss()
            }
            .padding(.bottom)
        }
        .frame(minWidth: 300, minHeight: 300)
    }
} 
