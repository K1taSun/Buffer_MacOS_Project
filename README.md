# Buffer

<div align="center">

**A powerful, privacy-focused clipboard manager for macOS**

[![Swift](https://img.shields.io/badge/Swift-5.9+-orange.svg)](https://swift.org)
[![Platform](https://img.shields.io/badge/Platform-macOS-lightgrey.svg)](https://www.apple.com/macos)
[![License](https://img.shields.io/badge/License-MIT-blue.svg)](LICENSE)

*Streamline your workflow with intelligent clipboard history management*

</div>

---

## 📋 Table of Contents

- [Overview](#overview)
- [Features](#features)
- [Requirements](#requirements)
- [Installation](#installation)
- [Usage](#usage)
- [Keyboard Shortcuts](#keyboard-shortcuts)
- [Architecture](#architecture)
- [Development](#development)
- [Testing](#testing)
- [Troubleshooting](#troubleshooting)
- [Contributing](#contributing)
- [License](#license)
- [Author](#author)

---

## 🎯 Overview

Buffer is a native macOS application that enhances your productivity by maintaining a comprehensive history of your clipboard operations. Built with SwiftUI and designed with privacy in mind, Buffer provides an elegant, keyboard-driven interface for accessing your clipboard history without compromising your data security.

### Key Highlights

- **🔒 Privacy-First**: All data stored locally, no network access, no cloud sync
- **⚡ Performance**: Lightweight and efficient, minimal system resource usage
- **🎨 Modern UI**: Beautiful SwiftUI interface with smooth animations
- **⌨️ Keyboard-Driven**: Full keyboard navigation and shortcuts
- **🧠 Smart Organization**: Intelligent sorting and categorization of clipboard items

---

## ✨ Features

### Core Functionality

- **📝 Multi-Format Support**
  - Plain text snippets
  - URLs with automatic detection
  - File paths and references
  - Images with preview (PNG, JPG, GIF, WebP, TIFF)
  - Rich text (RTF) content

- **🔍 Advanced Search & Filtering**
  - Real-time search with case-insensitive matching
  - Quick filter chips: All, Text, Images, Files, URLs, Pinned
  - Instant filtering and sorting

- **📌 Smart Pinning System**
  - Pin important items to keep them at the top
  - Automatic duplicate detection for pinned items
  - Persistent pinning across app restarts

- **🎯 Intelligent Sorting**
  - Format-aware grouping (Text → URLs → Files → Images → Rich Text)
  - Extension-based file sorting
  - Scheme-based URL sorting
  - Image format detection and grouping
  - Chronological ordering within groups

- **💾 Persistent Storage**
  - Automatic history persistence via UserDefaults
  - Corrupt data recovery mechanisms
  - Configurable item limit (default: 50 items)

### User Experience

- **🎨 Visual Polish**
  - Smooth animations and transitions
  - Hover effects and visual feedback
  - Image previews with full-screen view
  - Copy confirmation toast notifications
  - Context menu support

- **⌨️ Keyboard Navigation**
  - Global hotkeys: `⌘`` (Command + Backtick) or `⌘⇧V` (Command + Shift + V)
  - Full keyboard accessibility
  - Quick actions via keyboard shortcuts

- **🪟 Menu Bar Integration**
  - Lightweight menu bar presence
  - Quick access from anywhere
  - Non-intrusive design

---

## 📦 Requirements

- **macOS**: 13.0 (Ventura) or later
- **Xcode**: 14.0 or later (for building from source)
- **Swift**: 5.9 or later
- **Permissions**: Accessibility permission (required for global keyboard shortcuts)

---

## 🚀 Installation

### Option 1: Build from Source (Recommended)

1. **Clone the repository**
   ```bash
   git clone https://github.com/yourusername/Buffer_MacOS_Project.git
   cd Buffer_MacOS_Project
   ```

2. **Run the setup script**
   ```bash
   chmod +x setup.sh
   ./setup.sh
   ```
   This script verifies your development environment and checks project structure.

3. **Build the application**
   ```bash
   chmod +x build.sh
   ./build.sh
   ```
   The built application will be located at `build/Build/Products/Debug/Buffer.app`

4. **Open in Xcode (Alternative)**
   ```bash
   open Buffer.xcodeproj
   ```
   Select the *Buffer* scheme and press `⌘R` to build and run.

### Option 2: Direct Xcode Build

1. Open `Buffer.xcodeproj` in Xcode
2. Select your target (macOS)
3. Build and run using `⌘R`

---

## 📖 Usage

### First Launch

1. **Grant Accessibility Permission**
   - When prompted, navigate to **System Settings → Privacy & Security → Accessibility**
   - Enable Buffer in the list of allowed applications
   - This permission is required for global keyboard shortcuts to function

2. **Start Using**
   - Buffer automatically monitors your clipboard
   - Copy items as you normally would
   - Access your history using the keyboard shortcuts

### Accessing Clipboard History

| Action | Method |
|--------|--------|
| **Open History Window** | Press `⌘`` or `⌘⇧V` |
| **Search Items** | Start typing in the search bar |
| **Filter by Type** | Click filter chips (All, Text, Images, Files, URLs, Pinned) |
| **Copy Item** | Click item, press `Return`, or use context menu |
| **Pin/Unpin Item** | Click pin icon or use context menu |
| **Delete Item** | Press `Delete` key or use context menu |
| **Clear Unpinned** | Click "Clear Unpinned" button in footer |
| **Clear All** | Click "Clear All" button in footer |

### Sorting Behavior

Buffer organizes items using a sophisticated multi-level sorting algorithm:

1. **Pinned Items**: Always appear at the top, maintaining pin order
2. **Type Priority**: `Text < URL < File < Image < Rich Text`
3. **Format Grouping**:
   - Files: Sorted by extension (normalized, case-insensitive)
   - URLs: Sorted by scheme (http, https, file, etc.)
   - Images: Sorted by format (png, jpg, gif, webp, tiff)
4. **Chronological**: Newest items first within each format group
5. **Deterministic Fallback**: Case-insensitive title comparison for tie-breaking

---

## ⌨️ Keyboard Shortcuts

| Shortcut | Action |
|----------|--------|
| `⌘`` | Toggle clipboard history window |
| `⌘⇧V` | Toggle clipboard history window (alternative) |
| `Return` | Copy selected item |
| `Delete` | Delete selected item |
| `Esc` | Close window (when focused) |

---

## 🏗️ Architecture

### Project Structure

```
Buffer_MacOS_Project/
├── Buffer/                      # Main application source
│   ├── BufferApp.swift         # Application entry point & AppDelegate
│   ├── Models/
│   │   └── ClipboardItem.swift # Core data model
│   ├── Views/
│   │   └── ClipboardView.swift # Main UI components
│   ├── Managers/
│   │   ├── ClipboardManager.swift  # Clipboard monitoring & management
│   │   └── WindowManager.swift     # Window lifecycle management
│   ├── Helpers/
│   │   └── ClipboardItemNameHelper.swift  # Display name generation
│   ├── Assets.xcassets/        # App icons and assets
│   ├── Buffer.entitlements     # App capabilities
│   └── Info.plist              # App metadata
├── BufferTests/                # Unit tests
├── BufferUITests/              # UI tests
├── build.sh                    # Build automation script
├── setup.sh                    # Development environment setup
└── README.md                   # This file
```

### Key Components

#### ClipboardManager
- Singleton pattern for centralized clipboard management
- Timer-based clipboard monitoring (300ms interval)
- Automatic duplicate detection using content hashing
- Persistent storage via UserDefaults
- Thread-safe operations with main thread synchronization

#### ClipboardItem
- Codable model supporting multiple content types
- Automatic type detection (text, URL, file, image, rich text)
- Pinning state management
- Display name generation based on content type

#### ClipboardView
- SwiftUI-based main interface
- Real-time search and filtering
- Lazy loading for performance
- Image preview with full-screen modal
- Context menu support

### Design Patterns

- **Singleton**: ClipboardManager, WindowManager
- **Observer**: Combine framework for reactive updates
- **MVVM**: SwiftUI's declarative architecture
- **Factory**: Display name generation helpers

---

## 🔧 Development

### Prerequisites

Ensure you have the following installed:
- Xcode 14.0 or later
- Command Line Tools for Xcode
- Swift 5.9 or later

### Building

```bash
# Clean build
./build.sh

# Or using xcodebuild directly
xcodebuild -project Buffer.xcodeproj \
           -scheme Buffer \
           -configuration Debug \
           build
```

### Development Workflow

1. Make your changes in Xcode or your preferred editor
2. Build and test using `⌘R` in Xcode
3. Run tests to ensure everything works
4. Commit your changes

### Code Style

- Follow Swift API Design Guidelines
- Use meaningful variable and function names
- Add comments for complex logic
- Maintain consistent indentation (spaces, not tabs)

---

## 🧪 Testing

### Run All Tests

```bash
xcodebuild -project Buffer.xcodeproj -scheme Buffer test
```

### Run Unit Tests Only

```bash
xcodebuild -project Buffer.xcodeproj \
           -scheme Buffer \
           -destination 'platform=macOS' \
           -only-testing:BufferTests test
```

### Run UI Tests

```bash
xcodebuild -project Buffer.xcodeproj \
           -scheme Buffer \
           -destination 'platform=macOS' \
           -only-testing:BufferUITests test
```

---

## 🔍 Troubleshooting

### Keyboard Shortcuts Not Working

**Problem**: Global keyboard shortcuts (`⌘`` or `⌘⇧V`) don't respond.

**Solution**:
1. Open **System Settings → Privacy & Security → Accessibility**
2. Ensure Buffer is enabled in the list
3. If Buffer is not listed, add it manually using the `+` button
4. Restart Buffer after granting permission

### Clipboard History Not Persisting

**Problem**: History is lost after app restart.

**Solution**:
1. Check UserDefaults permissions
2. Verify app has write access to preferences
3. Check Console.app for error messages
4. Try resetting history: Delete the `savedClipboardItems` key from UserDefaults:
   ```bash
   defaults delete com.yourcompany.Buffer savedClipboardItems
   ```

### Build Errors

**Problem**: Project fails to build.

**Solution**:
1. Clean build folder: `⌘⇧K` in Xcode or `./build.sh --clean`
2. Delete DerivedData:
   ```bash
   rm -rf ~/Library/Developer/Xcode/DerivedData
   ```
3. Reset package caches:
   ```bash
   rm -rf Buffer.xcodeproj/project.xcworkspace/xcshareddata/swiftpm
   ```
4. Rebuild the project

### Performance Issues

**Problem**: App is slow or unresponsive.

**Solution**:
1. Reduce history limit in `ClipboardManager.swift` (Config.maxItems)
2. Clear old history items
3. Check for excessive clipboard activity
4. Monitor system resources in Activity Monitor

---

## 🤝 Contributing

Contributions are welcome! Please follow these guidelines:

1. **Fork the repository**
2. **Create a feature branch**
   ```bash
   git checkout -b feature/amazing-feature
   ```
3. **Make your changes**
   - Follow existing code style
   - Add tests for new functionality
   - Update documentation as needed
4. **Commit your changes**
   ```bash
   git commit -m "Add amazing feature"
   ```
5. **Push to the branch**
   ```bash
   git push origin feature/amazing-feature
   ```
6. **Open a Pull Request**

### Contribution Guidelines

- Write clear, descriptive commit messages
- Ensure all tests pass
- Update README.md if adding new features
- Follow Swift naming conventions
- Add comments for complex logic

---

## 📝 Roadmap

Future enhancements under consideration:

- [ ] Export/import history functionality
- [ ] Custom keyboard shortcut configuration
- [ ] Drag & drop support for items
- [ ] iCloud sync (optional, privacy-preserving)
- [ ] History statistics and analytics
- [ ] Custom themes and appearance options
- [ ] Advanced search with regex support
- [ ] Clipboard item editing
- [ ] Multiple clipboard buffers
- [ ] Integration with other productivity tools

---

## 📄 License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

```
MIT License

Copyright (c) 2025 Nikita Parkovskyi

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.
```

---

## 👤 Author

**Nikita Parkovskyi**

- GitHub: [@yourusername](https://github.com/yourusername)
- Project Link: [https://github.com/yourusername/Buffer_MacOS_Project](https://github.com/yourusername/Buffer_MacOS_Project)

---

## 🙏 Acknowledgments

- Built with [SwiftUI](https://developer.apple.com/xcode/swiftui/)
- Inspired by the need for a privacy-focused clipboard manager
- Thanks to the Swift and macOS development community

---

<div align="center">

**Made with ❤️ for macOS**

⭐ Star this repo if you find it useful!

</div>
