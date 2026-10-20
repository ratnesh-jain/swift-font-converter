//
//  ConvertFont.swift
//  ConvertFont
//
//  Converts any TrueType (.ttf) or OpenType (.otf) font into pure Swift code
//  for 1-bit e-Paper displays using Apple's ArgumentParser and CoreGraphics.
//

import ArgumentParser
import Foundation
import FontConverterKit

#if canImport(CoreGraphics) && canImport(CoreText)
import CoreGraphics
import CoreText
#endif

extension FontType: ExpressibleByArgument {}

// MARK: - Root CLI

@main
struct ConvertFontCLI: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "convert-font",
        abstract: "Convert TrueType/OpenType fonts to Swift 1-bit e-Paper code, or search font paths by name.",
        version: "1.0.0",
        subcommands: [Convert.self, Search.self],
        defaultSubcommand: Convert.self
    )
}

// MARK: - Search Subcommand

struct Search: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "search",
        abstract: "Search installed system fonts by name to find their exact file paths."
    )

    @Argument(help: "Font name or keyword to search (e.g. 'SF Pro', 'Menlo', 'Medium', 'Fira').")
    var query: String

    @Flag(name: [.customShort("p"), .customLong("paths-only")], help: "Print only the absolute file paths (ideal for xargs or piping).")
    var pathsOnly: Bool = false

    @Option(name: .shortAndLong, help: "Maximum number of results to display.")
    var limit: Int = 30

    func run() throws {
        #if canImport(CoreGraphics) && canImport(CoreText)
        let matches = FontFinder.search(query: query)
        guard !matches.isEmpty else {
            print("No fonts found matching query '\(query)'.")
            return
        }

        let slice = matches.prefix(limit)

        if pathsOnly {
            var printed = Set<String>()
            for m in slice {
                if !printed.contains(m.path) {
                    print(m.path)
                    printed.insert(m.path)
                }
            }
            return
        }

        print("\nFound \(matches.count) matching font(s)" + (matches.count > limit ? " (showing first \(limit)):" : ":") + "\n")
        let col1Header = "DISPLAY NAME".padding(toLength: 32, withPad: " ", startingAt: 0)
        let col2Header = "POSTSCRIPT NAME".padding(toLength: 30, withPad: " ", startingAt: 0)
        print("\(col1Header) \(col2Header) FILE PATH")
        print(String(repeating: "-", count: 110))

        for m in slice {
            let truncatedDisplay = m.displayName.count > 30 ? String(m.displayName.prefix(29)) + "…" : m.displayName
            let truncatedPost = m.postScriptName.count > 28 ? String(m.postScriptName.prefix(27)) + "…" : m.postScriptName
            let col1 = truncatedDisplay.padding(toLength: 32, withPad: " ", startingAt: 0)
            let col2 = truncatedPost.padding(toLength: 30, withPad: " ", startingAt: 0)
            print("\(col1) \(col2) \(m.path)")
        }

        print(String(repeating: "-", count: 110))
        print("💡 Tip: You can convert any font above directly by name or path:")
        if let first = slice.first {
            print("   swift run convert-font \"\(first.displayName)\" -s 18 -p \"Hello\"\n")
        }
        #else
        print("Error: Font search requires macOS CoreText framework.")
        #endif
    }
}

// MARK: - Convert Subcommand

struct Convert: ParsableCommand {
    static let configuration = CommandConfiguration(
        commandName: "convert",
        abstract: "Converts TrueType (.ttf) or OpenType (.otf) fonts to Swift 1-bit e-Paper code."
    )

    @Argument(help: "Path to TTF or OTF font file, or name of an installed font (e.g. 'SF Pro Text Medium', 'Menlo').")
    var font: String

    @Option(name: .shortAndLong, help: "Font point size.")
    var size: Double = 16.0

    @Option(name: .shortAndLong, help: "Swift property name (default: derived from font name + size).")
    var name: String?

    @Option(name: .shortAndLong, help: "Font style: 'proportional' for variable-width (SF Pro) or 'fixed' for monospace.")
    var type: FontType = .proportional

    @Option(name: .long, help: "1-bit binarization threshold (0-255). Higher = bolder strokes on e-Paper.")
    var threshold: UInt8 = 170

    @Option(name: .shortAndLong, help: "Render live ASCII art preview in the terminal (optional text).")
    var preview: String?

    @Option(name: .shortAndLong, help: "Output .swift file path (default: stdout).")
    var output: String?

    func run() throws {
        #if canImport(CoreGraphics) && canImport(CoreText)
        guard let resolved = FontFinder.resolveFontPath(font) else {
            throw ValidationError(
                "Could not find font at path or installed font matching '\(font)'.\n" +
                "Try searching installed fonts with: swift run convert-font search \"\(font)\""
            )
        }

        let resolvedPath = resolved.path
        if resolvedPath != font {
            print("ℹ️ Resolved font '\(font)' to: \(resolved.displayName) [\(resolvedPath)]")
        }

        guard let converter = FontConverter(fontPath: resolvedPath, size: CGFloat(size), threshold: threshold) else {
            throw ValidationError("Failed to read font file at '\(resolvedPath)'. Ensure it is a valid TTF/OTF.")
        }

        if let previewText = preview {
            converter.renderPreview(text: previewText)
        }

        let baseName: String
        if let custom = name {
            baseName = custom
        } else {
            let filename = URL(fileURLWithPath: resolvedPath).deletingPathExtension().lastPathComponent
            let cleaned = filename.replacingOccurrences(of: "[^a-zA-Z0-9_]", with: "_", options: .regularExpression)
            baseName = "\(cleaned.prefix(1).lowercased())\(cleaned.dropFirst())_\(Int(size))pt"
        }

        let swiftCode: String
        switch type {
        case .fixed:
            swiftCode = converter.generateFixedFont(baseName: baseName, sourcePath: resolvedPath)
        case .proportional:
            swiftCode = converter.generateProportionalFont(baseName: baseName, sourcePath: resolvedPath)
        }

        if let outPath = output {
            try swiftCode.write(toFile: outPath, atomically: true, encoding: .utf8)
            print("Successfully generated Swift font '\(baseName)' in: \(outPath)")
        } else {
            print(swiftCode)
        }
        #else
        print("Error: Font conversion requires macOS CoreGraphics and CoreText frameworks.")
        #endif
    }
}
