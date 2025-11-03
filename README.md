# Buffer – macOS Clipboard Manager

Buffer is a lightweight, privacy-friendly clipboard history app for macOS. It lives in your menu bar, watches the system pasteboard, and gives you a fast, keyboard-driven interface for anything you copied recently—text snippets, URLs, files, screenshots, and rich text.

## Why Buffer?
- **Stay in flow** – summon the history window with `⌘`` or `⌘⇧V`, paste the item you need, keep working.
- **Format-aware sorting** – items are grouped by type (Text → URLs → Files → Images → Rich Text) and then by extension/scheme so your brain finds things faster.
- **Smart duplicates** – pin something important and Buffers refreshes the same entry when you copy it again instead of cluttering history.
- **Visual polish** – hover/selection feedback, copy toast, animated pin buttons, image previews.
- **No bloat** – 50 item default cap, respects the sandbox, no network calls.

## Feature Highlights
- Menu bar UI with SwiftUI-driven history window
- Global shortcuts (`⌘`` and `⌘⇧V`) with accessibility permission prompts
- Text, URL, file, image (with preview), and rich text capture
- Pin/unpin, delete, clear unpinned, clear all
- Search bar plus quick filter chips (All, Text, Images, Files, URLs, Pinned)
- Persistent history stored via `UserDefaults` with corrupt-data recovery

## Installation
### Prerequisites
```bash
./setup.sh
```
The script installs tooling, fetches SwiftPM dependencies, and is safe to rerun after Xcode updates.

### Build from source
```bash
git clone https://github.com/yourusername/Buffer_MacOS_Project.git
cd Buffer_MacOS_Project
./build.sh
```
The script performs a clean build and optionally launches the app.

### Open in Xcode
```bash
open Buffer.xcodeproj
```
Pick the *Buffer* scheme and hit `⌘R` to run.

## Usage Cheat Sheet
| Action | How |
| --- | --- |
| Toggle window | `⌘`` or `⌘⇧V` |
| Search history | Start typing; matches are case-insensitive |
| Filter by type | Use the chips (All / Text / Images / Files / URLs / Pinned) |
| Copy item | Click, press Return, or use the context menu |
| Pin / unpin | Pin icon or context menu |
| Delete | Delete key or context menu |
| Clear unpinned | Footer button |
| Clear all | Footer button (pinned remain pinned) |

### Sorting Details
1. Pinned entries always stay at the top, in the order you pinned them.
2. Unpinned items are grouped by type using this priority: `text < url < file < image < richText`.
3. Files sort by normalized extension (fallback to filename); URLs sort by scheme; images sort by detected format (png, jpg, gif, webp, tiff).
4. Within each format group, newest items appear first. If timestamps tie, Buffer falls back to case-insensitive title comparison for deterministic ordering.

## Permissions
- **Accessibility** (`System Settings → Privacy & Security → Accessibility`) – required to intercept keyboard shortcuts.
- **Clipboard access** – handled automatically via AppKit APIs.

## Project Structure
```
Buffer_MacOS_Project/
├── Buffer/                # App sources
│   ├── BufferApp.swift    # Entry point
│   ├── Models/
│   ├── Views/
│   ├── Managers/
│   └── Helpers/
├── BufferTests/           # Unit tests
├── BufferUITests/         # UI tests
├── build.sh               # build helper
├── setup.sh               # bootstrap helper
└── FIXES.md               # changelog of applied fixes
```

## Test
Run everything:
```bash
xcodebuild -project Buffer.xcodeproj -scheme Buffer test
```
Only logic tests (faster iteration):
```bash
xcodebuild -project Buffer.xcodeproj -scheme Buffer \
  -destination 'platform=macOS' \
  -only-testing:BufferTests test
```

## Maintenance
- Build output (`DerivedData/`, `build/`, `.xcresult`, etc.) already ignored via `.gitignore`.
- `./build.sh --clean` when the project misbehaves.
- Remove corrupted history by deleting the `savedClipboardItems` key from `UserDefaults` (Preferences or `defaults delete`).

## Roadmap Ideas
- Export/import history
- Custom shortcut configuration
- Drag & drop support for items
- History sync via iCloud or local network

## License
MIT – see [`LICENSE`](LICENSE).

## Support
Create an issue with macOS version, Xcode version, and reproduction steps: <https://github.com/yourusername/Buffer_MacOS_Project/issues>
