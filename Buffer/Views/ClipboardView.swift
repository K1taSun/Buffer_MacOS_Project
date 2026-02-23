import SwiftUI

struct ClipboardView: View {
    @EnvironmentObject private var clipboardManager: ClipboardManager
    @EnvironmentObject private var languageManager: LanguageManager
    @State private var searchText = ""
    @State private var isAppearing = false
    @State private var selectedFilter: ClipboardFilter = .all
    @State private var previewedImage: ImagePreviewData? = nil
    @State private var showCopyFeedback = false
    @State private var showSettings = false
    var allowDrag: Bool = true
    
    private var filteredItems: [ClipboardItem] {
        let items = clipboardManager.items
        
        // Apply search filter
        let searchFiltered: [ClipboardItem]
        if searchText.isEmpty {
            searchFiltered = items
        } else {
            let lowerSearch = searchText.lowercased()
            searchFiltered = items.filter { 
                $0.content.lowercased().contains(lowerSearch)
            }
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
    
    // Group items by date section, with pinned items at the top
    private var groupedItems: [(DateSection?, [ClipboardItem])] {
        let filtered = filteredItems
        
        // Separate pinned and unpinned items
        let pinnedItems = filtered.filter { $0.isPinned }
        let unpinnedItems = filtered.filter { !$0.isPinned }
        
        var sections: [(DateSection?, [ClipboardItem])] = []
        
        // Add pinned section if there are pinned items
        if !pinnedItems.isEmpty {
            sections.append((nil, pinnedItems))
        }
        
        // Group unpinned items by date section
        let groupedDict = Dictionary(grouping: unpinnedItems) { $0.dateSection }
        
        // Add sections in order
        for section in DateSection.allCases {
            if let items = groupedDict[section], !items.isEmpty {
                sections.append((section, items))
            }
        }
        
        return sections
    }
    
    var body: some View {
        ZStack {
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
            .overlay(
                Group {
                    if showCopyFeedback {
                        VStack {
                            Spacer()
                            HStack {
                                Spacer()
                                Text(languageManager.localized("clipboard.copied"))
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
            
            if showSettings {
                SettingsView(isPresented: $showSettings)
                    .transition(.move(edge: .bottom))
                    .zIndex(2000)
            }
        }
    }
    
    private var headerView: some View {
        HStack {
            Text(languageManager.localized("clipboard.title"))
                .font(.headline)
                .fontWeight(.semibold)
            
            Spacer()
            
            HStack(spacing: 8) {
                TextField(languageManager.localized("clipboard.search"), text: $searchText)
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
                        title: languageManager.localized(filter.localizedKey),
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
                    LazyVStack(spacing: 8) {
                        ForEach(Array(groupedItems.enumerated()), id: \.offset) { index, section in
                            VStack(alignment: .leading, spacing: 4) {
                                // Section header
                                if let dateSection = section.0 {
                                    Text(languageManager.localized(dateSection.localizedKey))
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(.secondary)
                                        .textCase(.uppercase)
                                        .padding(.horizontal, 16)
                                        .padding(.top, index == 0 ? 8 : 12)
                                        .padding(.bottom, 4)
                                } else {
                                    // Pinned section header
                                    HStack(spacing: 4) {
                                        Image(systemName: "pin.fill")
                                            .font(.caption2)
                                        Text(languageManager.localized("filter.pinned"))
                                            .font(.caption)
                                            .fontWeight(.semibold)
                                    }
                                    .foregroundColor(.blue)
                                    .textCase(.uppercase)
                                    .padding(.horizontal, 16)
                                    .padding(.top, 8)
                                    .padding(.bottom, 4)
                                }
                                
                                // Items in section
                                ForEach(section.1) { item in
                                    let itemView = ClipboardItemView(item: item, onImageTap: { nsImage in
                                        previewedImage = ImagePreviewData(image: nsImage)
                                    })
                                    .contextMenu {
                                        Button(languageManager.localized("context.copy")) { 
                                            clipboardManager.copyItem(item)
                                            triggerCopyFeedback()
                                        }
                                        Button(item.isPinned ? languageManager.localized("context.unpin") : languageManager.localized("context.pin")) { 
                                            clipboardManager.togglePin(item) 
                                        }
                                        Divider()
                                        Button(languageManager.localized("context.delete")) { clipboardManager.removeItem(item) }
                                    }
                                    .onTapGesture { 
                                        clipboardManager.copyItem(item)
                                        triggerCopyFeedback()
                                    }
                                    
                                    // Conditionally apply drag
                                    if allowDrag {
                                        itemView.onDrag {
                                            item.itemProvider
                                        }
                                    } else {
                                        itemView
                                    }
                                }
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
            return languageManager.localized("empty.noFound")
        }
        switch selectedFilter {
        case .all:
            return languageManager.localized("empty.noClipboard")
        case .text:
            return languageManager.localized("empty.noText")
        case .images:
            return languageManager.localized("empty.noImages")
        case .files:
            return languageManager.localized("empty.noFiles")
        case .urls:
            return languageManager.localized("empty.noUrls")
        case .pinned:
            return languageManager.localized("empty.noPinned")
        }
    }
    
    private var emptyStateSubtitle: String {
        if !searchText.isEmpty {
            return languageManager.localized("emptySub.trySearch")
        }
        switch selectedFilter {
        case .all:
            return languageManager.localized("emptySub.copyStart")
        case .text:
            return languageManager.localized("emptySub.copyText")
        case .images:
            return languageManager.localized("emptySub.copyImage")
        case .files:
            return languageManager.localized("emptySub.copyFile")
        case .urls:
            return languageManager.localized("emptySub.copyUrl")
        case .pinned:
            return languageManager.localized("emptySub.pinItems")
        }
    }
    
    private var footerView: some View {
        HStack {
            Text("\(filteredItems.count) \(languageManager.localized("clipboard.itemsCount"))")
                .font(.caption)
                .foregroundColor(.secondary)
            
            Spacer()
            
            HStack(spacing: 12) {
                Button(languageManager.localized("clipboard.clearUnpinned")) { 
                    clipboardManager.clearUnpinned() 
                }
                .padding(10)
                .contentShape(Rectangle())
                .buttonStyle(.plain)
                .foregroundColor(.orange)

                Button(languageManager.localized("clipboard.clearAll")) { 
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
                        .fill(isSelected ? Color.blue : Color.white.opacity(0.001))
                )
                .foregroundColor(isSelected ? .white : .primary)
                .overlay(
                    RoundedRectangle(cornerRadius: 14)
                        .stroke(isSelected ? Color.clear : Color.secondary.opacity(0.3), lineWidth: 1)
                )
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}

enum ClipboardFilter: CaseIterable {
    case all, text, images, files, urls, pinned
    
// Old code (for reference):
//     var title: String {
//         switch self {
//         case .all: return "All"
//         case .text: return "Text"
//         case .images: return "Images"
//         case .files: return "Files"
//         case .urls: return "URLs"
//         case .pinned: return "Pinned"
//         }
//     }

    var localizedKey: String {
        switch self {
        case .all: return "filter.all"
        case .text: return "filter.text"
        case .images: return "filter.images"
        case .files: return "filter.files"
        case .urls: return "filter.urls"
        case .pinned: return "filter.pinned"
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
                
// Old code (for reference):
//                 Text(item.timestamp, style: .time)
//                     .font(.caption)
//                     .foregroundColor(.secondary)

                // Jeśli plik wpadł do dawnej historii, modyfikujemy tekst żeby pokazywał mu również konkretną datę.
                Text(getHumanReadableDate(for: item))
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
    
    // Zwracamy bardziej szczegółową datę dla starych plików z przeszłości, 
    // żebyś wiedział dokładnie kiedy element został skopiowany.
    private func getHumanReadableDate(for item: ClipboardItem) -> String {
        let formatter = DateFormatter()
        
        if item.dateSection == .past {
            // Dla starszych itemów wyświetlamy pełniejszą formę: data + godzina
            formatter.dateStyle = .short
            formatter.timeStyle = .short
        } else {
            // "Dzisiaj" i "Wczoraj" mówią same za siebie - oszczędzamy miejsce i zostawiamy im czystą godzinę.
            formatter.dateStyle = .none
            formatter.timeStyle = .short
        }
        
        return formatter.string(from: item.timestamp)
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
    @EnvironmentObject private var languageManager: LanguageManager
    
    var body: some View {
        VStack {
            Image(nsImage: image)
                .resizable()
                .scaledToFit()
                .frame(maxWidth: 500, maxHeight: 500)
                .padding()
            
            Button(languageManager.localized("context.close")) {
                dismiss()
            }
            .padding(.bottom)
        }
        .frame(minWidth: 300, minHeight: 300)
    }
} 
