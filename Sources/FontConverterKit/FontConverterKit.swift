//
//  FontConverterKit.swift
//  FontConverterKit
//
//  Library providing font discovery, metrics extraction, and 1-bit rasterization
//  for e-Paper displays on macOS.
//

import Foundation

#if canImport(CoreGraphics) && canImport(CoreText)
import CoreGraphics
import CoreText
#endif

public enum FontType: String, Sendable, CaseIterable {
    case proportional
    case fixed
}

public struct FontMatch: Sendable, Equatable {
    public let displayName: String
    public let postScriptName: String
    public let familyName: String
    public let path: String

    public init(displayName: String, postScriptName: String, familyName: String, path: String) {
        self.displayName = displayName
        self.postScriptName = postScriptName
        self.familyName = familyName
        self.path = path
    }
}

public struct GlyphData: Sendable, Equatable {
    public let advance: UInt8
    public let width: UInt8
    public let height: UInt8
    public let left: Int8
    public let top: Int8
    public let bytes: [UInt8]

    public init(advance: UInt8, width: UInt8, height: UInt8, left: Int8, top: Int8, bytes: [UInt8]) {
        self.advance = advance
        self.width = width
        self.height = height
        self.left = left
        self.top = top
        self.bytes = bytes
    }
}

public struct FixedGlyphData: Sendable, Equatable {
    public let bytes: [UInt8]

    public init(bytes: [UInt8]) {
        self.bytes = bytes
    }
}

// MARK: - Font Finder

public struct FontFinder {
    #if canImport(CoreGraphics) && canImport(CoreText)
    public static func search(query: String) -> [FontMatch] {
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

    public static func resolveFontPath(_ input: String) -> (path: String, displayName: String)? {
        let expanded = NSString(string: input).expandingTildeInPath
        if FileManager.default.fileExists(atPath: expanded) {
            return (expanded, URL(fileURLWithPath: expanded).lastPathComponent)
        }

        // Try direct descriptor match
        let desc = CTFontDescriptorCreateWithNameAndSize(input as CFString, 12.0)
        if let url = CTFontDescriptorCopyAttribute(desc, kCTFontURLAttribute) as? URL,
           FileManager.default.fileExists(atPath: url.path) {
            let name = (CTFontDescriptorCopyAttribute(desc, kCTFontDisplayNameAttribute) as? String) ?? input
            return (url.path, name)
        }

        // Search installed fonts
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
    #else
    public static func search(query: String) -> [FontMatch] { return [] }
    public static func resolveFontPath(_ input: String) -> (path: String, displayName: String)? { return nil }
    #endif
}

// MARK: - Font Converter

#if canImport(CoreGraphics) && canImport(CoreText)
public final class FontConverter: @unchecked Sendable {
    public let ctFont: CTFont
    public let ascent: CGFloat
    public let descent: CGFloat
    public let leading: CGFloat
    public let lineHeight: Int
    public let threshold: UInt8

    public init?(fontPath: String, size: CGFloat, threshold: UInt8 = 170) {
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

    public func extractProportionalGlyph(_ char: Character) -> GlyphData {
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

    public func extractFixedGlyph(_ char: Character, cellWidth: Int) -> FixedGlyphData {
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

    public func previewString(text: String) -> String {
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

        var lines = [String]()
        for row in canvas {
            let s = String(row)
            if s.contains("#") {
                lines.append(s)
            }
        }
        return lines.joined(separator: "\n")
    }

    public func renderPreview(text: String) {
        print("\n" + String(repeating: "=", count: 64))
        print(" Terminal Preview for: \"\(text)\" (Threshold: \(threshold))")
        print(String(repeating: "=", count: 64))
        print(previewString(text: text))
        print(String(repeating: "=", count: 64) + "\n")
    }

    public func generateProportionalFont(baseName: String, sourcePath: String) -> String {
        var glyphLines = [String]()
        for code: UInt8 in 32...126 {
            let ch = Character(UnicodeScalar(code))
            let g = extractProportionalGlyph(ch)
            let bytesStr = g.bytes.map { String(format: "0x%02X", $0) }.joined(separator: ", ")
            var chDesc = String(ch)
            if chDesc == "\\" { chDesc = "\\\\" }
            if chDesc == "\"" { chDesc = "\\\"" }
            glyphLines.append("            ProportionalGlyph(advance: \(g.advance), width: \(g.width), height: \(g.height), left: \(g.left), top: \(g.top), bytes: [\(bytesStr)]), // '\(chDesc)' (\(code))")
        }

        return """
        //
        //  Generated by convert-font
        //  Source: \(URL(fileURLWithPath: sourcePath).lastPathComponent)
        //

        import Foundation

        extension ProportionalFont {
            public static let \(baseName) = ProportionalFont(
                name: "\(baseName)",
                lineHeight: \(lineHeight),
                glyphs: [
        \(glyphLines.joined(separator: "\n"))
                ]
            )
        }
        """
    }

    public func generateFixedFont(baseName: String, sourcePath: String) -> String {
        var maxW = 0
        for code: UInt8 in 32...126 {
            let ch = Character(UnicodeScalar(code))
            var u = ch.utf16.first!
            var g: CGGlyph = 0
            CTFontGetGlyphsForCharacters(ctFont, &u, &g, 1)
            var adv = CGSize.zero
            CTFontGetAdvancesForGlyphs(ctFont, .horizontal, &g, &adv, 1)
            maxW = max(maxW, Int(round(adv.width)))
        }
        let cellW = max(1, maxW)
        let bpr = (cellW + 7) / 8

        var glyphLines = [String]()
        for code: UInt8 in 32...126 {
            let ch = Character(UnicodeScalar(code))
            let g = extractFixedGlyph(ch, cellWidth: cellW)
            let bytesStr = g.bytes.map { String(format: "0x%02X", $0) }.joined(separator: ", ")
            var chDesc = String(ch)
            if chDesc == "\\" { chDesc = "\\\\" }
            if chDesc == "\"" { chDesc = "\\\"" }
            glyphLines.append("            [\(bytesStr)], // '\(chDesc)' (\(code))")
        }

        return """
        //
        //  Generated by convert-font
        //  Source: \(URL(fileURLWithPath: sourcePath).lastPathComponent)
        //

        import Foundation

        extension BitmapFont {
            public static let \(baseName) = BitmapFont(
                name: "\(baseName)",
                width: \(cellW),
                height: \(lineHeight),
                bytesPerRow: \(bpr),
                glyphs: [
        \(glyphLines.joined(separator: "\n"))
                ]
            )
        }
        """
    }
}
#endif
