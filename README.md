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

## Installation & Quickstart

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

## CLI Reference & Subcommands

The CLI executable is `convert-font`. It provides two subcommands: `convert` (the default) and `search`.

### 1. `convert` (Default Subcommand)

Converts a font file or an installed font into Swift 1-bit e-Paper code.

```bash
swift run convert-font [<font>] [options]
# or explicitly:
swift run convert-font convert <font> [options]
```

#### Arguments
| Argument | Type | Description |
| :--- | :--- | :--- |
| `<font>` | `String` | Path to a `.ttf` or `.otf` file, or the name of an installed system font (e.g. `"SF Pro Text Medium"`, `"Menlo"`, `"/System/Library/Fonts/Menlo.ttc"`). |

#### Options & Flags
| Option | Short | Type | Default | Description |
| :--- | :---: | :---: | :---: | :--- |
| `--size` | `-s` | `Double` | `16.0` | Font point size. |
| `--name` | `-n` | `String` | *(derived)* | Swift property name (default: derived from font name + size, e.g. `sfProTextMedium_18pt`). |
| `--type` | `-t` | `String` | `proportional` | Font style: `proportional` (variable-width advances and bounding boxes) or `fixed` (uniform monospace cell columns). |
| `--threshold` | | `UInt8` | `170` | 1-bit binarization threshold (`0`–`255`). Higher values produce bolder strokes on high-contrast displays. |
| `--preview` | `-p` | `String` | | Render an immediate ASCII art preview in the terminal for the specified text. |
| `--output` | `-o` | `String` | *(stdout)* | Destination file path for generated `.swift` code. If omitted, outputs directly to stdout. |
| `--help` | `-h` | | | Show command help information. |

#### Examples
```bash
# Preview digits in terminal using Menlo at 14pt:
swift run convert-font "Menlo" -s 14 -p "192.168.1.1"

# Generate proportional SF Pro 18pt to a Swift file:
swift run convert-font "SF Pro Text Medium" -s 18 -o SFPro18.swift

# Generate fixed-width monospace font code with bolder strokes (threshold 190):
swift run convert-font "Courier New" -s 12 -t fixed --threshold 190 -o Courier12.swift
```

---

### 2. `search` Subcommand

Searches installed macOS system and user fonts by display name, PostScript name, family name, or file path.

```bash
swift run convert-font search <query> [options]
```

#### Arguments
| Argument | Type | Description |
| :--- | :--- | :--- |
| `<query>` | `String` | Font name or keyword to query (case-insensitive, e.g. `"Menlo"`, `"SF Pro"`, `"Mono"`, `"Fira"`). |

#### Options & Flags
| Option | Short | Type | Default | Description |
| :--- | :---: | :---: | :---: | :--- |
| `--paths-only` | `-p` | `Flag` | `false` | Output only unique absolute file paths, one per line (ideal for piping to `xargs` or shell scripts). |
| `--limit` | `-l` | `Int` | `30` | Maximum number of search results to display in the formatted table. |
| `--help` | `-h` | | | Show command help information. |

#### Examples
```bash
# Search for all installed Menlo fonts:
swift run convert-font search "Menlo"

# Search for Monaco and get only its filesystem path:
swift run convert-font search "Monaco" -p

# List the first 10 fonts matching "Display":
swift run convert-font search "Display" -l 10
```

---

## Library Target (`FontConverterKit`)

You can also integrate `FontConverterKit` directly into your own Swift tools or macOS apps:

```swift
import FontConverterKit

// 1. Search fonts
let results = FontFinder.search(query: "Menlo")

// 2. Load font converter (by name or direct path)
if let converter = FontConverter(fontName: "Menlo", size: 16) {
    // 3. Render ASCII art
    print(converter.previewString(text: "192.168.1.1"))

    // 4. Generate Swift code
    let swiftCode = converter.generateProportionalFont(
        baseName: "menlo16",
        sourcePath: "Menlo"
    )
}
```

---

## Running Tests

```bash
swift test
```
