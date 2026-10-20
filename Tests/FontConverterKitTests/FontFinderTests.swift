//
//  FontFinderTests.swift
//  ConvertFontTests
//
//  Swift Testing suite for FontFinder and FontConverterKit.
//

import Foundation
import Testing
@testable import FontConverterKit

@Suite("Font Discovery & Resolution Tests")
struct FontFinderTests {

    @Test("Search system fonts returns results for standard fonts")
    func searchStandardFont() {
        let results = FontFinder.search(query: "Menlo")
        #expect(!results.isEmpty)
        #expect(results.contains(where: { $0.displayName.contains("Menlo") }))
    }

    @Test("Search is case-insensitive")
    func searchCaseInsensitive() {
        let lower = FontFinder.search(query: "menlo")
        let upper = FontFinder.search(query: "MENLO")
        #expect(!lower.isEmpty)
        #expect(lower.count == upper.count)
        #expect(lower.map(\.path) == upper.map(\.path))
    }

    @Test("Search for non-existent font returns empty list")
    func searchNonExistent() {
        let results = FontFinder.search(query: "NonExistentFont_XYZ_12345")
        #expect(results.isEmpty)
    }

    @Test("Search matches contain valid filesystem paths")
    func searchResultsHaveValidPaths() {
        let results = FontFinder.search(query: "Menlo")
        for match in results {
            #expect(!match.displayName.isEmpty)
            #expect(!match.postScriptName.isEmpty)
            #expect(FileManager.default.fileExists(atPath: match.path), "Path should exist on disk: \(match.path)")
        }
    }

    @Test("Resolve font by display name finds valid path")
    func resolveByDisplayName() {
        let resolved = FontFinder.resolveFontPath("Menlo")
        #expect(resolved != nil)
        if let resolved = resolved {
            #expect(FileManager.default.fileExists(atPath: resolved.path))
            #expect(resolved.path.contains("Menlo"))
        }
    }

    @Test("Resolve font by PostScript name finds valid path")
    func resolveByPostScriptName() {
        let resolved = FontFinder.resolveFontPath("Menlo-Regular")
        #expect(resolved != nil)
        if let resolved = resolved {
            #expect(FileManager.default.fileExists(atPath: resolved.path))
        }
    }

    @Test("Resolve direct file path succeeds")
    func resolveDirectFilePath() {
        let path = "/System/Library/Fonts/Menlo.ttc"
        if FileManager.default.fileExists(atPath: path) {
            let resolved = FontFinder.resolveFontPath(path)
            #expect(resolved != nil)
            #expect(resolved?.path == path)
        }
    }

    @Test("Resolve non-existent font returns nil")
    func resolveNonExistentReturnsNil() {
        let resolved = FontFinder.resolveFontPath("DoesNotExist_ABC_987")
        #expect(resolved == nil)
    }
}

@Suite("Font Rasterization & Code Generation Tests")
struct FontConverterTests {

    private func getTestFontPath() -> String? {
        FontFinder.resolveFontPath("Menlo")?.path
            ?? (FileManager.default.fileExists(atPath: "/System/Library/Fonts/Menlo.ttc") ? "/System/Library/Fonts/Menlo.ttc" : nil)
    }

    @Test("FontConverter loads valid font successfully")
    func fontConverterInit() throws {
        guard let path = getTestFontPath() else {
            return // Skip if no test font available
        }
        let converter = try #require(FontConverter(fontPath: path, size: 16, threshold: 170))
        #expect(converter.lineHeight > 0)
        #expect(converter.ascent > 0)
    }

    @Test("FontConverter loads font by name successfully")
    func fontConverterInitByName() {
        if FontFinder.resolveFontPath("Menlo") != nil {
            let converter = FontConverter(fontName: "Menlo", size: 16)
            #expect(converter != nil)
            #expect(converter?.lineHeight ?? 0 > 0)
        }
    }

    @Test("Extract proportional glyph produces valid bounds and bitmap")
    func extractProportionalGlyph() throws {
        guard let path = getTestFontPath() else { return }
        let converter = try #require(FontConverter(fontPath: path, size: 16, threshold: 170))

        let glyphA = converter.extractProportionalGlyph("A")
        #expect(glyphA.advance > 0)
        #expect(glyphA.width > 0)
        #expect(glyphA.height > 0)
        #expect(!glyphA.bytes.isEmpty)

        // Space character should have advance > 0 but 0 width/height/bytes
        let glyphSpace = converter.extractProportionalGlyph(" ")
        #expect(glyphSpace.advance > 0)
        #expect(glyphSpace.width == 0)
        #expect(glyphSpace.height == 0)
        #expect(glyphSpace.bytes.isEmpty)
    }

    @Test("Extract fixed glyph produces correct byte count")
    func extractFixedGlyph() throws {
        guard let path = getTestFontPath() else { return }
        let converter = try #require(FontConverter(fontPath: path, size: 16, threshold: 170))

        let cellWidth = 10
        let bpr = (cellWidth + 7) / 8
        let glyph = converter.extractFixedGlyph("0", cellWidth: cellWidth)
        #expect(glyph.bytes.count == bpr * converter.lineHeight)
    }

    @Test("Generate Proportional Font Swift code produces expected structure")
    func generateProportionalFontCode() throws {
        guard let path = getTestFontPath() else { return }
        let converter = try #require(FontConverter(fontPath: path, size: 16, threshold: 170))

        let code = converter.generateProportionalFont(baseName: "testMenlo_16pt", sourcePath: path)
        #expect(code.contains("extension ProportionalFont"))
        #expect(code.contains("public static let testMenlo_16pt = ProportionalFont("))
        #expect(code.contains("lineHeight: \(converter.lineHeight)"))
        #expect(code.contains("ProportionalGlyph(advance:"))
    }
}
