#!/usr/bin/env swift
//
//  ConvertFont.swift
//  Raspi-GPIO-Via-Docker
//
//  Converts any TrueType (.ttf) or OpenType (.otf) font into pure Swift code
//  for 1-bit e-Paper displays using macOS CoreGraphics & CoreText.
//
//  Zero external dependencies required (no Python or Pillow needed).
//

import Foundation
import CoreGraphics
import CoreText

// MARK: - Models

struct GlyphData {
    let advance: UInt8
    let width: UInt8
    let height: UInt8
    let left: Int8
    let top: Int8
    let bytes: [UInt8]
}

struct FixedGlyphData {
    let bytes: [UInt8]
}

struct FontMatch {
    let displayName: String
    let postScriptName: String
    let familyName: String
    let path: String
}

// MARK: - Font Finder

struct FontFinder {
    static func search(query: String) -> [FontMatch] {
        let collection = CTFontCollectionCreateFromAvailableFonts(nil)
        guard let descriptors = CTFontCollectionCreateMatchingFontDescriptors(collection) as? [CTFontDescriptor] else {
            return []
        }
        var results = [FontMatch]()
        var seen = Set<String>()
        let cleanQuery = query.trimmingCharacters(in: .whitespacesAndNewlines)

        for desc in descriptors {
            guard let url = CTFontDescriptorCopyAttribute(desc, kCTFontURLAttribute) as? URL else { continue }
            let displayName = (CTFontDescriptorCopyAttribute(desc, kCTFontDisplayNameAttribute) as? String) ?? ""
            let postScriptName = (CTFontDescriptorCopyAttribute(desc, kCTFontNameAttribute) as? String) ?? ""
            let familyName = (CTFontDescriptorCopyAttribute(desc, kCTFontFamilyNameAttribute) as? String) ?? ""

            let path = url.path
            let key = "\(postScriptName)|\(path)"
            if seen.contains(key) { continue }
            seen.insert(key)

            if cleanQuery.isEmpty ||
               displayName.localizedCaseInsensitiveContains(cleanQuery) ||
               postScriptName.localizedCaseInsensitiveContains(cleanQuery) ||
               familyName.localizedCaseInsensitiveContains(cleanQuery) ||
               path.localizedCaseInsensitiveContains(cleanQuery) {
                results.append(FontMatch(
                    displayName: displayName,
                    postScriptName: postScriptName,
                    familyName: familyName,
                    path: path
                ))
            }
        }
        return results.sorted {
            if $0.displayName.count != $1.displayName.count {
                return $0.displayName.count < $1.displayName.count
            }
            return $0.displayName.localizedCaseInsensitiveCompare($1.displayName) == .orderedAscending
        }
    }

    static func resolveFontPath(_ input: String) -> (path: String, displayName: String)? {
        let expanded = NSString(string: input).expandingTildeInPath
        if FileManager.default.fileExists(atPath: expanded) {
            return (expanded, URL(fileURLWithPath: expanded).lastPathComponent)
        }

        let desc = CTFontDescriptorCreateWithNameAndSize(input as CFString, 12.0)
        if let url = CTFontDescriptorCopyAttribute(desc, kCTFontURLAttribute) as? URL,
           FileManager.default.fileExists(atPath: url.path) {
            let name = (CTFontDescriptorCopyAttribute(desc, kCTFontDisplayNameAttribute) as? String) ?? input
            return (url.path, name)
        }

        let matches = search(query: input)
        if let exact = matches.first(where: {
            $0.postScriptName.localizedCaseInsensitiveCompare(input) == .orderedSame ||
            $0.displayName.localizedCaseInsensitiveCompare(input) == .orderedSame
        }) {
            return (exact.path, exact.displayName)
        }

        if let first = matches.first {
            return (first.path, first.displayName)
        }

        return nil
    }
}

// MARK: - Font Converter

final class FontConverter {
    let ctFont: CTFont
    let ascent: CGFloat
    let descent: CGFloat
    let leading: CGFloat
    let lineHeight: Int
    let threshold: UInt8

    init?(fontPath: String, size: CGFloat, threshold: UInt8 = 170) {
        let url = URL(fileURLWithPath: fontPath) as CFURL
        guard let provider = CGDataProvider(url: url),
              let cgFont = CGFont(provider) else {
            return nil
        }
        let font = CTFontCreateWithGraphicsFont(cgFont, size, nil, nil)
        self.ctFont = font
        self.ascent = CTFontGetAscent(font)
        self.descent = CTFontGetDescent(font)
        self.leading = CTFontGetLeading(font)
        self.lineHeight = Int(ceil(ascent + descent))
        self.threshold = threshold
    }

    func extractProportionalGlyph(_ char: Character) -> GlyphData {
        guard let u16 = char.utf16.first else {
            return GlyphData(advance: 0, width: 0, height: 0, left: 0, top: 0, bytes: [])
        }
        var u = u16
        var glyph: CGGlyph = 0
        CTFontGetGlyphsForCharacters(ctFont, &u, &glyph, 1)

        var adv = CGSize.zero
        CTFontGetAdvancesForGlyphs(ctFont, .horizontal, &glyph, &adv, 1)
        let advance = UInt8(max(0, min(255, Int(round(adv.width)))))

        if char == " " {
            return GlyphData(advance: advance, width: 0, height: 0, left: 0, top: 0, bytes: [])
        }

        var bbox = CGRect.zero
        CTFontGetBoundingRectsForGlyphs(ctFont, .horizontal, &glyph, &bbox, 1)

        let gw = max(1, Int(ceil(bbox.width)) + 40)
        let gh = lineHeight + 20
        var pixels = [UInt8](repeating: 255, count: gw * gh)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(
            data: &pixels,
            width: gw,
            height: gh,
            bitsPerComponent: 8,
            bytesPerRow: gw,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            return GlyphData(advance: advance, width: 0, height: 0, left: 0, top: 0, bytes: [])
        }

        ctx.setFillColor(gray: 1.0, alpha: 1.0)
        ctx.fill(CGRect(x: 0, y: 0, width: gw, height: gh))
        ctx.setFillColor(gray: 0.0, alpha: 1.0)

        let cgBaselineY = ceil(descent) + 6
        let padX: CGFloat = 10
        var pos = CGPoint(x: padX, y: cgBaselineY)
        CTFontDrawGlyphs(ctFont, &glyph, &pos, 1, ctx)

        let baselineMemoryRow = (gh - 1) - Int(cgBaselineY)
        let baselineOffsetInLine = Int(ceil(ascent))

        var minX = gw, maxX = -1, minY = gh, maxY = -1
        for y in 0..<gh {
            for x in 0..<gw {
                if pixels[y * gw + x] < threshold {
                    if x < minX { minX = x }
                    if x > maxX { maxX = x }
                    if y < minY { minY = y }
                    if y > maxY { maxY = y }
                }
            }
        }

        if maxX < minX || maxY < minY {
            return GlyphData(advance: advance, width: 0, height: 0, left: 0, top: 0, bytes: [])
        }

        let bw = maxX - minX + 1
        let bh = maxY - minY + 1
        let bLeft = Int8(minX - Int(padX))
        let bTop = Int8(minY - baselineMemoryRow + baselineOffsetInLine)

        var bytes = [UInt8]()
        for y in minY...maxY {
            var byteVal: UInt8 = 0
            var bitIdx = 7
            for x in minX...maxX {
                if pixels[y * gw + x] < threshold {
                    byteVal |= (1 << bitIdx)
                }
                bitIdx -= 1
                if bitIdx < 0 {
                    bytes.append(byteVal)
                    byteVal = 0
                    bitIdx = 7
                }
            }
            if bitIdx != 7 {
                bytes.append(byteVal)
            }
        }

        return GlyphData(
            advance: advance,
            width: UInt8(bw),
            height: UInt8(bh),
            left: bLeft,
            top: bTop,
            bytes: bytes
        )
    }

    func extractFixedGlyph(_ char: Character, cellWidth: Int) -> FixedGlyphData {
        guard let u16 = char.utf16.first else {
            let bpr = (cellWidth + 7) / 8
            return FixedGlyphData(bytes: [UInt8](repeating: 0, count: bpr * lineHeight))
        }
        var u = u16
        var glyph: CGGlyph = 0
        CTFontGetGlyphsForCharacters(ctFont, &u, &glyph, 1)

        let gw = cellWidth
        let gh = lineHeight
        var pixels = [UInt8](repeating: 255, count: gw * gh)
        let colorSpace = CGColorSpaceCreateDeviceGray()
        guard let ctx = CGContext(
            data: &pixels,
            width: gw,
            height: gh,
            bitsPerComponent: 8,
            bytesPerRow: gw,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.none.rawValue
        ) else {
            let bpr = (cellWidth + 7) / 8
            return FixedGlyphData(bytes: [UInt8](repeating: 0, count: bpr * lineHeight))
        }

        ctx.setFillColor(gray: 1.0, alpha: 1.0)
        ctx.fill(CGRect(x: 0, y: 0, width: gw, height: gh))
        ctx.setFillColor(gray: 0.0, alpha: 1.0)

        let cgBaselineY = ceil(descent)
        var pos = CGPoint(x: 0, y: cgBaselineY)
        CTFontDrawGlyphs(ctFont, &glyph, &pos, 1, ctx)

        var bytes = [UInt8]()
        for y in 0..<gh {
            var byteVal: UInt8 = 0
            var bitIdx = 7
            for x in 0..<gw {
                if pixels[y * gw + x] < threshold {
                    byteVal |= (1 << bitIdx)
                }
                bitIdx -= 1
                if bitIdx < 0 {
                    bytes.append(byteVal)
                    byteVal = 0
                    bitIdx = 7
                }
            }
            if bitIdx != 7 {
                bytes.append(byteVal)
            }
        }
        return FixedGlyphData(bytes: bytes)
    }

    func preview(text: String) {
        var glyphs = [Character: GlyphData]()
        for ch in text {
            if glyphs[ch] == nil {
                glyphs[ch] = extractProportionalGlyph(ch)
            }
        }

        let totalAdvance = text.reduce(0) { $0 + Int(glyphs[$1]?.advance ?? 0) }
        let canvasW = max(totalAdvance + 10, 60)
        let canvasH = lineHeight + 8
        var canvas = [[Character]](repeating: [Character](repeating: " ", count: canvasW), count: canvasH)
        var curX = 4

        for ch in text {
            guard let g = glyphs[ch] else { continue }
            if g.width > 0 && g.height > 0 {
                let bpr = (Int(g.width) + 7) / 8
                for row in 0..<Int(g.height) {
                    let rowOffset = row * bpr
                    for col in 0..<Int(g.width) {
                        let byteIdx = rowOffset + (col / 8)
                        let bit = 7 - (col % 8)
                        if (g.bytes[byteIdx] & (1 << bit)) != 0 {
                            let px = curX + Int(g.left) + col
                            let py = Int(g.top) + row
                            if px >= 0 && px < canvasW && py >= 0 && py < canvasH {
                                canvas[py][px] = "#"
                            }
                        }
                    }
                }
            }
            curX += Int(g.advance)
        }

        print("\n" + String(repeating: "=", count: 64))
        print(" Terminal Preview for: \"\(text)\" (Threshold: \(threshold))")
        print(String(repeating: "=", count: 64))
        for row in canvas {
            let s = String(row)
            if s.contains("#") {
                print(s)
            }
        }
        print(String(repeating: "=", count: 64) + "\n")
    }
}

// MARK: - CLI Argument Parser

struct Options {
    var mode: Mode = .convert
    var searchQuery: String = ""
    var fontInput: String = ""
    var size: Double = 16.0
    var name: String? = nil
    var type: String = "proportional"
    var threshold: UInt8 = 170
    var previewText: String? = nil
    var outputPath: String? = nil
    var pathsOnly: Bool = false

    enum Mode {
        case convert
        case search
    }
}

func printUsage() {
    print("""
    ConvertFont.swift - Native macOS Swift tool to convert TTF/OTF fonts to 1-bit e-Paper code.

    USAGE:
        ./ConvertFont.swift <font-path-or-name> [options]
        ./ConvertFont.swift search <query> [--paths-only]

    COMMANDS:
        search <query>            Search installed system fonts by name to find their exact paths.

    OPTIONS:
        -s, --size <points>       Font point size (default: 16)
        -n, --name <string>       Swift identifier name (default: derived from font)
        -t, --type <type>         'proportional' (default) or 'fixed'
        --threshold <0-255>       Pixel threshold (default: 170). Higher = thicker strokes.
        -p, --preview [text]      Render ASCII art preview in terminal
        -o, --output <path>       Output Swift file path (default: stdout)
        -h, --help                Show this help message

    EXAMPLES:
        ./ConvertFont.swift search "SF Pro Medium"
        ./ConvertFont.swift "SF Pro Text Medium" -s 18 --preview "RPi 5 Server"
        ./ConvertFont.swift /Library/Fonts/SF-Pro.ttf -s 20 -o Sources/RpiServer/CustomFont.swift
    """)
}

func parseArguments() -> Options? {
    let args = CommandLine.arguments
    guard args.count > 1 else {
        printUsage()
        return nil
    }

    var options = Options()
    var i = 1

    if args[1] == "search" {
        options.mode = .search
        i = 2
        while i < args.count {
            let arg = args[i]
            if arg == "-p" || arg == "--paths-only" {
                options.pathsOnly = true
            } else if options.searchQuery.isEmpty {
                options.searchQuery = arg
            }
            i += 1
        }
        guard !options.searchQuery.isEmpty else {
            print("Error: Missing search query for font search.\nUsage: ./ConvertFont.swift search <query>")
            return nil
        }
        return options
    }

    while i < args.count {
        let arg = args[i]
        switch arg {
        case "-h", "--help":
            printUsage()
            exit(0)
        case "-s", "--size":
            i += 1
            if i < args.count, let val = Double(args[i]) {
                options.size = val
            }
        case "-n", "--name":
            i += 1
            if i < args.count {
                options.name = args[i]
            }
        case "-t", "--type":
            i += 1
            if i < args.count {
                options.type = args[i]
            }
        case "--threshold":
            i += 1
            if i < args.count, let val = UInt8(args[i]) {
                options.threshold = val
            }
        case "-p", "--preview":
            if i + 1 < args.count && !args[i + 1].hasPrefix("-") {
                i += 1
                options.previewText = args[i]
            } else {
                options.previewText = "RPi 5 Server"
            }
        case "-o", "--output":
            i += 1
            if i < args.count {
                options.outputPath = args[i]
            }
        default:
            if !arg.hasPrefix("-") && options.fontInput.isEmpty {
                options.fontInput = arg
            } else {
                print("Unknown option: \(arg)")
                printUsage()
                return nil
            }
        }
        i += 1
    }

    guard !options.fontInput.isEmpty else {
        print("Error: Missing font file path or font name.")
        printUsage()
        return nil
    }

    return options
}

// MARK: - Main Execution

guard let opts = parseArguments() else {
    exit(1)
}

if opts.mode == .search {
    let matches = FontFinder.search(query: opts.searchQuery)
    guard !matches.isEmpty else {
        print("No fonts found matching query '\(opts.searchQuery)'.")
        exit(0)
    }

    if opts.pathsOnly {
        var seen = Set<String>()
        for m in matches {
            if !seen.contains(m.path) {
                print(m.path)
                seen.insert(m.path)
            }
        }
        exit(0)
    }

    let limit = 30
    let slice = matches.prefix(limit)
    print("\nFound \(matches.count) matching font(s)" + (matches.count > limit ? " (showing first \(limit)):" : ":") + "\n")
    let col1Header = "DISPLAY NAME".padding(toLength: 32, withPad: " ", startingAt: 0)
    let col2Header = "POSTSCRIPT NAME".padding(toLength: 30, withPad: " ", startingAt: 0)
    print("\(col1Header) \(col2Header) FILE PATH")
    print(String(repeating: "-", count: 110))

    for m in slice {
        let display = m.displayName.count > 30 ? String(m.displayName.prefix(29)) + "…" : m.displayName
        let post = m.postScriptName.count > 28 ? String(m.postScriptName.prefix(27)) + "…" : m.postScriptName
        let col1 = display.padding(toLength: 32, withPad: " ", startingAt: 0)
        let col2 = post.padding(toLength: 30, withPad: " ", startingAt: 0)
        print("\(col1) \(col2) \(m.path)")
    }

    print(String(repeating: "-", count: 110))
    print("💡 Tip: Convert any font above directly by name:")
    if let first = slice.first {
        print("   ./ConvertFont.swift \"\(first.displayName)\" -s 18 -p \"Hello\"\n")
    }
    exit(0)
}

guard let resolved = FontFinder.resolveFontPath(opts.fontInput) else {
    print("Error: Could not find font at path or installed font matching '\(opts.fontInput)'.")
    print("Try searching installed fonts with: ./ConvertFont.swift search \"\(opts.fontInput)\"")
    exit(1)
}

if resolved.path != opts.fontInput {
    print("ℹ️ Resolved font '\(opts.fontInput)' to: \(resolved.displayName) [\(resolved.path)]")
}

guard let converter = FontConverter(fontPath: resolved.path, size: CGFloat(opts.size), threshold: opts.threshold) else {
    print("Error: Failed to load font with CoreGraphics / CoreText.")
    exit(1)
}

if let previewStr = opts.previewText {
    converter.preview(text: previewStr)
}

let baseName: String
if let custom = opts.name {
    baseName = custom
} else {
    let filename = URL(fileURLWithPath: resolved.path).deletingPathExtension().lastPathComponent
    let cleaned = filename.replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "_", options: .regularExpression)
    baseName = "\(cleaned.prefix(1).lowercased())\(cleaned.dropFirst())_\(Int(opts.size))pt"
}

let swiftCode: String

if opts.type == "fixed" {
    var maxW = 0
    for code: UInt8 in 32...126 {
        let ch = Character(UnicodeScalar(code))
        var u = ch.utf16.first!
        var g: CGGlyph = 0
        CTFontGetGlyphsForCharacters(converter.ctFont, &u, &g, 1)
        var adv = CGSize.zero
        CTFontGetAdvancesForGlyphs(converter.ctFont, .horizontal, &g, &adv, 1)
        maxW = max(maxW, Int(round(adv.width)))
    }
    let cellW = max(1, maxW)
    let bpr = (cellW + 7) / 8

    var glyphLines = [String]()
    for code: UInt8 in 32...126 {
        let ch = Character(UnicodeScalar(code))
        let g = converter.extractFixedGlyph(ch, cellWidth: cellW)
        let bytesStr = g.bytes.map { String(format: "0x%02X", $0) }.joined(separator: ", ")
        var chDesc = String(ch)
        if chDesc == "\\" { chDesc = "\\\\" }
        if chDesc == "\"" { chDesc = "\\\"" }
        glyphLines.append("            [\(bytesStr)], // '\(chDesc)' (\(code))")
    }

    swiftCode = """
    //
    //  Generated by ConvertFont.swift
    //  Source: \(URL(fileURLWithPath: resolved.path).lastPathComponent) (\(Int(opts.size))pt)
    //

    import Foundation

    extension BitmapFont {
        public static let \(baseName) = BitmapFont(
            name: "\(baseName)",
            width: \(cellW),
            height: \(converter.lineHeight),
            bytesPerRow: \(bpr),
            glyphs: [
    \(glyphLines.joined(separator: "\n"))
            ]
        )
    }
    """
} else {
    var glyphLines = [String]()
    for code: UInt8 in 32...126 {
        let ch = Character(UnicodeScalar(code))
        let g = converter.extractProportionalGlyph(ch)
        let bytesStr = g.bytes.map { String(format: "0x%02X", $0) }.joined(separator: ", ")
        var chDesc = String(ch)
        if chDesc == "\\" { chDesc = "\\\\" }
        if chDesc == "\"" { chDesc = "\\\"" }
        glyphLines.append("            ProportionalGlyph(advance: \(g.advance), width: \(g.width), height: \(g.height), left: \(g.left), top: \(g.top), bytes: [\(bytesStr)]), // '\(chDesc)' (\(code))")
    }

    swiftCode = """
    //
    //  Generated by ConvertFont.swift
    //  Source: \(URL(fileURLWithPath: resolved.path).lastPathComponent) (\(Int(opts.size))pt)
    //

    import Foundation

    extension ProportionalFont {
        public static let \(baseName) = ProportionalFont(
            name: "\(baseName)",
            lineHeight: \(converter.lineHeight),
            glyphs: [
    \(glyphLines.joined(separator: "\n"))
            ]
        )
    }
    """
}

if let outPath = opts.outputPath {
    do {
        try swiftCode.write(toFile: outPath, atomically: true, encoding: .utf8)
        print("Successfully generated Swift font '\(baseName)' in: \(outPath)")
    } catch {
        print("Error writing output file '\(outPath)': \(error)")
        exit(1)
    }
} else {
    print(swiftCode)
}
