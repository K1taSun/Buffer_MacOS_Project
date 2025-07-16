# Buffer

A simple clipboard manager for macOS.

## What it does

- Saves your clipboard history
- Shows copied text, images, files, and URLs
- Quick access with Cmd + `
- Pin important items to keep them at the top

## How to use

1. Build and run the project in Xcode
2. The app appears in your menu bar
3. Copy something - it shows up in the history
4. Press Cmd + ` to open the clipboard window
5. Click any item to copy it back

## Features

- Automatic clipboard monitoring
- Search through your history
- Filter by content type
- Pin/unpin items
- Clear all or just unpinned items

## Requirements

- macOS 12.0+
- Xcode 14.0+

## Build

```bash
git clone <repo-url>
cd Buffer_MacOS_Project
open Buffer.xcodeproj
```

Then build and run in Xcode.

## Struktura projektu

- `Buffer/` – kod źródłowy aplikacji
  - `Assets.xcassets/` – zasoby graficzne
  - `Managers/` – menedżery logiki
  - `Models/` – modele danych
  - `Views/` – widoki UI
  - `Extensions/` – rozszerzenia (opcjonalnie)
  - `Services/` – serwisy (opcjonalnie)
  - `Helpers/` – pomocnicze klasy/funkcje (opcjonalnie)
- `BufferTests/` – testy jednostkowe
- `BufferUITests/` – testy UI
- `Buffer.xcodeproj/` – pliki projektu Xcode

## Uruchomienie

1. Otwórz projekt w Xcode (`Buffer.xcodeproj`).
2. Zbuduj i uruchom aplikację na wybranym symulatorze lub urządzeniu.

## License

MIT