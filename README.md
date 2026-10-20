# swift-font-converter

A fast, zero-external-graphics-dependency Swift package for converting TrueType (`.ttf`) and OpenType (`.otf`) fonts into 1-bit packed binary bitmap code for embedded microcontrollers, e-Paper / e-Ink displays (such as Waveshare 1.54", 2.13", 2.9"), and OLEDs.

## Features

- **Font Discovery & Search (`search`)**: Interrogate macOS CoreText to search installed system and user fonts by family name, display name, or PostScript name.
- **Auto Font Resolution**: Pass standard font names like `"SF Pro Text Medium"`, `"Menlo"`, or `"Monaco"` directly—no need to track down obscure font file paths.
- **Proportional & Monospace Output**:
  - Proportional fonts with variable horizontal advances, bounding boxes, and vertical offsets.
  - Fixed-pitch monospaced fonts with packed column slices.
- **In-Terminal ASCII Art Preview (`-p`)**: Render an immediate visual representation of characters in terminal before writing code to disk.
- **Tunable 1-Bit Threshold (`--threshold`)**: Fine-tune stroke thickness and stroke continuity on monochrome screens.
- **Automated Testing**: Comprehensive unit tests with **Swift Testing** and character snapshot tests with Point-Free's **`InlineSnapshotTesting`**.

---

## Installation & CLI Usage

### Build and Run with SwiftPM

```bash
cd swift-font-converter

# 1. Search for installed fonts
swift run convert-font search "SF Pro"

# 2. Preview in terminal
swift run convert-font "SF Pro Text Medium" -s 18 -p "Hello World"

# 3. Generate Swift code to a file
swift run convert-font "SF Pro Text Medium" -s 18 -o Sources/MyProject/SFPro18.swift
```

---

## Library Target (`FontConverterKit`)

You can also integrate `FontConverterKit` directly into your own Swift tools or macOS apps:

```swift
import FontConverterKit

// 1. Search fonts
let results = FontFinder.search(query: "Menlo")

// 2. Load font converter
if let converter = FontConverter(fontName: "Menlo", size: 16) {
    // 3. Render ASCII art
    print(converter.previewString(text: "192.168.1.1"))

    // 4. Generate Swift code
    let swiftCode = converter.generateProportionalFontSwiftCode(
        fontName: "menlo16",
        characters: " 0123456789.:"
    )
}
```

---

## Running Tests

```bash
swift test
```

Includes:
- **12 Swift Testing unit tests** testing font discovery, resolution, and rasterization.
- **9 InlineSnapshotTesting tests** asserting against exact byte layouts and ASCII previews across Menlo, SF Pro, Monaco, Courier New, and SF Pro Rounded.
