# Buffer - macOS Clipboard Manager

A powerful and elegant clipboard manager for macOS that runs in the menu bar, providing quick access to your clipboard history with support for text, images, files, and URLs.

## Features

- 📋 **Multi-format Support**: Text, images, files, URLs, and rich text
- 🔍 **Smart Search**: Filter and search through your clipboard history
- 📌 **Pin Items**: Keep important items at the top of your history
- 🎨 **Beautiful UI**: Modern, native macOS interface with smooth animations
- ⌨️ **Global Shortcuts**: Quick access with Cmd+` or Cmd+Shift+V
- 💾 **Persistent Storage**: Your clipboard history is saved between app launches
- 🖼️ **Image Preview**: Click on images to view them in full size
- 🎯 **Smart Filtering**: Filter by content type (text, images, files, URLs, pinned)

## Requirements

- macOS 15.4 or later
- Xcode 15.0 or later (for building from source)

## Installation

### Option 1: Build from Source

1. Clone the repository:
   ```bash
   git clone https://github.com/yourusername/Buffer_MacOS_Project.git
   cd Buffer_MacOS_Project
   ```

2. Build the project:
   ```bash
   ./build.sh
   ```

3. The app will be built and you can choose to open it immediately.

### Option 2: Download Release

Download the latest release from the [Releases page](https://github.com/yourusername/Buffer_MacOS_Project/releases).

## Usage

### First Launch

1. Launch Buffer from Applications or the build directory
2. The app will appear in your menu bar with a clipboard icon
3. Click the menu bar icon to open the clipboard history window
4. Grant accessibility permissions when prompted (required for global shortcuts)

### Global Shortcuts

- **Cmd+`**: Toggle the clipboard history window
- **Cmd+Shift+V**: Alternative shortcut to toggle the window

### Using the Interface

- **Copy Items**: Click on any item to copy it to your clipboard
- **Pin Items**: Click the pin icon to keep an item at the top
- **Search**: Use the search bar to find specific items
- **Filter**: Use the filter buttons to show only specific content types
- **Delete**: Right-click an item and select "Delete" to remove it
- **Clear**: Use the "Clear Unpinned" or "Clear All" buttons in the footer

### Image Support

- Images are automatically detected and stored
- Click on an image thumbnail to view it in full size
- Image format is automatically detected (JPEG, PNG, GIF, etc.)

## Permissions

Buffer requires the following permissions to function properly:

### Accessibility Permissions
Required for global keyboard shortcuts. The app will prompt you to grant this permission on first launch.

To manually grant:
1. Go to System Preferences > Security & Privacy > Privacy > Accessibility
2. Click the lock icon to make changes
3. Add Buffer to the list of allowed applications

### Clipboard Access
The app needs access to monitor and modify the clipboard. This is handled automatically.

## Troubleshooting

### App Won't Launch

1. **Check macOS Version**: Ensure you're running macOS 15.4 or later
2. **Check Permissions**: Make sure Buffer has accessibility permissions
3. **Rebuild**: Try rebuilding the project with `./build.sh`

### Global Shortcuts Not Working

1. **Grant Accessibility Permissions**: 
   - Go to System Preferences > Security & Privacy > Privacy > Accessibility
   - Add Buffer to the allowed applications
   - Restart Buffer

2. **Check for Conflicts**: Ensure no other apps are using Cmd+` or Cmd+Shift+V

### Clipboard Not Updating

1. **Restart the App**: Close and reopen Buffer
2. **Check Permissions**: Ensure clipboard access is allowed
3. **Clear Data**: Try clearing all clipboard items and restart

### Build Issues

1. **Update Xcode**: Ensure you have the latest version of Xcode
2. **Clean Build**: Run `./build.sh` to clean and rebuild
3. **Check Dependencies**: Ensure all required frameworks are available

### Performance Issues

1. **Limit History**: The app stores up to 50 items by default
2. **Clear Old Items**: Use "Clear Unpinned" to remove old items
3. **Restart**: Close and reopen the app if it becomes sluggish

## Development

### Project Structure

```
Buffer_MacOS_Project/
├── Buffer/
│   ├── BufferApp.swift          # Main app entry point
│   ├── Models/
│   │   └── ClipboardItem.swift  # Data model
│   ├── Views/
│   │   └── ClipboardView.swift  # Main UI
│   ├── Managers/
│   │   ├── ClipboardManager.swift  # Clipboard monitoring
│   │   └── WindowManager.swift     # Window management
│   ├── Helpers/
│   │   └── ClipboardItemNameHelper.swift  # Display name generation
│   └── Assets.xcassets/         # App icons and assets
├── BufferTests/                 # Unit tests
├── BufferUITests/               # UI tests
└── build.sh                     # Build script
```

### Building for Development

1. Open the project in Xcode:
   ```bash
   open Buffer.xcodeproj
   ```

2. Select the "Buffer" scheme and target

3. Build and run (Cmd+R)

### Testing

Run the test suite:
```bash
xcodebuild -project Buffer.xcodeproj -scheme Buffer test
```

## Contributing

1. Fork the repository
2. Create a feature branch: `git checkout -b feature-name`
3. Make your changes
4. Add tests if applicable
5. Commit your changes: `git commit -am 'Add feature'`
6. Push to the branch: `git push origin feature-name`
7. Submit a pull request

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.

## Support

If you encounter any issues or have questions:

1. Check the [Issues page](https://github.com/yourusername/Buffer_MacOS_Project/issues)
2. Create a new issue with detailed information about your problem
3. Include your macOS version and any error messages

## Changelog

### Version 1.0
- Initial release
- Multi-format clipboard support
- Menu bar interface
- Global keyboard shortcuts
- Persistent storage
- Image preview functionality