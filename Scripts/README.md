# Font Converters for e-Paper Display

Convert any **TrueType (`.ttf`)** or **OpenType (`.otf`)** font into 1-bit Swift code for e-Paper displays.

---

## ⚡️ Swift CLI Target (`swift run convert-font`)

Built into the SPM package using Apple's **`swift-argument-parser`** and macOS native **`CoreGraphics` / `CoreText`** (zero external dependencies).

### 1. 🔍 Search Fonts by Name (`search`)

Search all installed macOS system and user fonts by family name, display name, or PostScript name to find their exact paths:

```bash
swift run convert-font search "SF Pro Medium"
```

*Example Output:*
```text
Found 1 matching font(s):

DISPLAY NAME                     POSTSCRIPT NAME                FILE PATH
--------------------------------------------------------------------------------------------------------------
SF Pro Medium                    SFPro-Medium                   /Library/Fonts/SF-Pro.ttf
--------------------------------------------------------------------------------------------------------------
```

Get just the file paths for piping or scripting:
```bash
swift run convert-font search Menlo -p
# /System/Library/Fonts/Menlo.ttc
```

### 2. Convert by Font Name or File Path

You can pass an installed font name directly—it will auto-resolve the font file on disk:

```bash
# By font name:
swift run convert-font "SF Pro Text Medium" -s 18 -p "Swift on Pi 5"

# Or by explicit file path:
swift run convert-font /Library/Fonts/SF-Pro-Text-Medium.otf -s 20 -o Sources/RpiServer/CustomFont.swift
```

### 3. Live Terminal Preview (`-p`)

Preview how the rendered font looks as 1-bit ASCII art in your terminal before generating the file:

```bash
swift run convert-font "SF Pro Text Medium" -s 18 -p "RPi 5 Server"
```

### 4. Adjusting Stroke Thickness (`--threshold`)

e-Paper displays do not support grayscale anti-aliasing. You can tune stroke thickness with `--threshold`:
- Default: `170` (balanced, solid strokes)
- Higher (`180-200`): Bolder / thicker strokes (prevents hairline dropouts)
- Lower (`130-150`): Lighter / finer strokes

```bash
swift run convert-font "SF Pro Text Medium" -s 24 --threshold 185 -p "Hello World"
```

### 5. Monospace / Fixed-Width Font (`-t fixed`)

To generate a fixed-pitch `BitmapFont` (ideal for coding/terminal fonts like Menlo, Monaco, Courier):

```bash
swift run convert-font "Menlo Regular" -s 12 -t fixed -o Sources/RpiServer/MenloFonts.swift
```

---

## Command Reference

### `search`
```text
USAGE: convert-font search <query> [--paths-only] [--limit <limit>]

ARGUMENTS:
  <query>                 Font name or keyword to search (e.g. 'SF Pro', 'Menlo', 'Medium').

OPTIONS:
  -p, --paths-only        Print only absolute file paths (ideal for xargs/piping).
  -l, --limit <limit>     Maximum results to display (default: 30).
  -h, --help              Show help information.
```

### `convert` (Default)
```text
USAGE: convert-font <font> [--size <size>] [--name <name>] [--type <type>] [--threshold <threshold>] [--preview <preview>] [--output <output>]

ARGUMENTS:
  <font>                  Path to TTF/OTF font file, or name of an installed font (e.g. 'SF Pro Text Medium', 'Menlo').

OPTIONS:
  -s, --size <size>       Font point size. (default: 16.0)
  -n, --name <name>       Swift property name (default: derived from font name + size).
  -t, --type <type>       Font style: 'proportional' or 'fixed'. (default: proportional)
  --threshold <threshold> 1-bit binarization threshold (0-255). Higher = bolder strokes. (default: 170)
  -p, --preview <preview> Render live ASCII art preview in the terminal.
  -o, --output <output>   Output .swift file path (default: stdout).
  -h, --help              Show help information.
```

---

## 🧪 Testing Suite (`swift test`)

The project includes unit tests via **Swift Testing** and snapshot tests via **`InlineSnapshotTesting`**:

```bash
swift test
```

### Snapshot Tested Fonts (`FontConverterSnapshotTests.swift`)
1. **Menlo** (`Menlo.ttc`):
   - Proportional glyph dump (`"A"`)
   - Monospace fixed glyph dump (`"8"`)
   - ASCII terminal text preview (`"Hello, e-Paper!"` & `"192.168.1.1"`)
2. **SF Pro Text Medium** (`SF-Pro-Text-Medium.otf`):
   - Proportional text render snapshot (`"Pi 5 Online"`)
3. **SF Pro Rounded Bold** (`SF-Pro-Rounded-Bold.otf`):
   - Proportional rounded headline snapshot (`"Rounded 18"`)
4. **Monaco** (`Monaco.ttf`):
   - Fixed-pitch terminal stats render snapshot (`"CPU: 34%"`)
5. **Courier New** (`Courier New.ttf`):
   - Fixed glyph binary dump snapshot (`"@"`)
6. **SF Pro Display Heavy** (`SF-Pro-Display-Heavy.otf`):
   - Heavyweight bold display counter preview snapshot (`"COUNT: 42"`)

---

## 🛠 Standalone Script Alternatives

You can also run standalone scripts without building via `swift run`:
- **Direct Swift script**: `./Scripts/ConvertFont.swift search "SF Pro"` or `./Scripts/ConvertFont.swift "SF Pro Text Medium" -s 18 -p "Hello"`
- **Python script**: `./Scripts/convert_font.py /path/to/font.ttf [options]` (requires `pip install Pillow`)
