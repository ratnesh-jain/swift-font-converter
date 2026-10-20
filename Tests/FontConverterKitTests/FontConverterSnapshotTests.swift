//
//  FontConverterSnapshotTests.swift
//  ConvertFontTests
//
//  Inline snapshot tests for font conversion, glyph metrics, and ASCII render output
//  using Point-Free's InlineSnapshotTesting.
//

import Foundation
import InlineSnapshotTesting
import SnapshotTesting
import XCTest
@testable import FontConverterKit

final class FontConverterSnapshotTests: XCTestCase {

    private func resolveTestFont(named names: String..., fallbackPath: String? = nil) -> String? {
        for name in names {
            if let resolved = FontFinder.resolveFontPath(name) {
                return resolved.path
            }
        }
        if let fallbackPath, FileManager.default.fileExists(atPath: fallbackPath) {
            return fallbackPath
        }
        return nil
    }

    private func getMenloFontPath() -> String? {
        resolveTestFont(named: "Menlo", fallbackPath: "/System/Library/Fonts/Menlo.ttc")
    }

    private func getSFProFontPath() -> String? {
        resolveTestFont(named: "SF Pro Text Medium", "SF Pro Medium")
    }

    private func getSFProRoundedFontPath() -> String? {
        resolveTestFont(named: "SF Pro Rounded Bold")
    }

    private func getMonacoFontPath() -> String? {
        resolveTestFont(named: "Monaco", fallbackPath: "/System/Library/Fonts/Monaco.ttf")
    }

    private func getCourierFontPath() -> String? {
        resolveTestFont(named: "Courier New", fallbackPath: "/System/Library/Fonts/Supplemental/Courier New.ttf")
    }

    private func getSFProDisplayHeavyFontPath() -> String? {
        resolveTestFont(named: "SF Pro Display Heavy")
    }

    // MARK: - Menlo Tests

    func testSnapshotProportionalGlyphDump() throws {
        guard let path = getMenloFontPath() else { return }
        let converter = try XCTUnwrap(FontConverter(fontPath: path, size: 16, threshold: 170))

        let glyphA = converter.extractProportionalGlyph("A")
        assertInlineSnapshot(of: glyphA, as: .dump) {
            """
            ▿ GlyphData
              - advance: 10
              ▿ bytes: 24 elements
                - 28
                - 0
                - 28
                - 0
                - 30
                - 0
                - 30
                - 0
                - 54
                - 0
                - 51
                - 0
                - 51
                - 0
                - 127
                - 0
                - 127
                - 128
                - 97
                - 128
                - 225
                - 128
                - 193
                - 128
              - height: 12
              - left: 0
              - top: 4
              - width: 9

            """
        }
    }

    func testSnapshotFixedGlyphDump() throws {
        guard let path = getMenloFontPath() else { return }
        let converter = try XCTUnwrap(FontConverter(fontPath: path, size: 12, threshold: 170))

        let glyph8 = converter.extractFixedGlyph("8", cellWidth: 7)
        assertInlineSnapshot(of: glyph8, as: .dump) {
            """
            ▿ FixedGlyphData
              ▿ bytes: 14 elements
                - 0
                - 0
                - 60
                - 108
                - 100
                - 124
                - 60
                - 100
                - 70
                - 100
                - 124
                - 0
                - 0
                - 0

            """
        }
    }

    func testSnapshotAsciiArtPreview() throws {
        guard let path = getMenloFontPath() else { return }
        let converter = try XCTUnwrap(FontConverter(fontPath: path, size: 14, threshold: 170))

        let preview = converter.previewString(text: "Hello, e-Paper!")
        assertInlineSnapshot(of: preview, as: .lines) {
            """
                 #    #          ####    ####                                             ###                                       #         
                 ##   ##           ##      ##                                            ######                                    ##         
                 ##   ##           ##      ##                                            ##  ###                                   ##         
                 ##   ##  ####     ##      ##     ####                    ####           ##   ## #####   #####    ####    ######   ##         
                 ####### ######    ##      ##    ######                  ######          ##   ## ## ###  ######  ######   ######   ##         
                 ####### ##   ##   ##      ##    ##   ##                 ##   ##         #######      #  ##   ## ##   ##  ##        #         
                 ##   ## #######   ##      ##    ##   ##                 ############### ######   #####  ##   ## #######  ##        #         
                 ##   ## ##        ##      ##    ##   ##                 ##              ##      ###  #  ##   ## ##       ##        #         
                 ##   ## ##         #       #    ##   ##   ##            ##              ##      ##  ##  ##   ## ##       ##                  
                 ##   ## ###  #     ##      ##   ### ##    ##            ###  #          ##      ## ###  ### ##  ###  #   ##       ###        
                 ##   ##  #####     ####    ####  ####     ##             #####          ##      ######  ######   #####   ##       ###        
                                                          ###                                            ##                                   
                                                          ##                                             ##                                   
                                                                                                         ##                                   
            """
        }
    }

    func testSnapshotMenloDigitsPreview() throws {
        guard let path = getMenloFontPath() else { return }
        let converter = try XCTUnwrap(FontConverter(fontPath: path, size: 12, threshold: 170))

        let preview = converter.previewString(text: "192.168.1.1")
        assertInlineSnapshot(of: preview, as: .lines) {
            """
                  ###    ###   ####           ###    ####   ####          ###           ###        
                 ####   ## ##  #  ##         ####   ##     ## ##         ####          ####        
                   ##   #   #      #           ##   #      ##  #           ##            ##        
                   ##   #   ##    ##           ##   #####  #####           ##            ##        
                   ##   ## ###    ##           ##   ## ##   ####           ##            ##        
                   ##    #####   ##            ##   #   ## ##  #           ##            ##        
                   ##       #   ##     ##      ##   #   ## #   ##  ##      ##    ##      ##        
                   ##      ##  ##      ###     ##   ## ##  ##  #   ###     ##    ###     ##        
                 ###### ####   #####   ###   ######  ####  #####   ###   ######  ###   ######      
            """
        }
    }

    // MARK: - SF Pro Text Medium Tests

    func testSnapshotSFProMediumPreview() throws {
        guard let path = getSFProFontPath() else { return }
        let converter = try XCTUnwrap(FontConverter(fontPath: path, size: 16, threshold: 170))

        let preview = converter.previewString(text: "Pi 5 Online")
        assertInlineSnapshot(of: preview, as: .lines) {
            """
                           ##                                          ##  ##                          
                 #######   ##       #######        ######              ##  ##                          
                 ########   #       #######       ########             ##   #                          
                 ##    ###          ##            ##    ###            ##                              
                 ##    ### ##      ##            ###     ##  ## ####   ##  ##  ## ####     ####        
                 ##    ### ##      ## ###        ##      ### #######   ##  ##  #######   #######       
                 ##    ### ##      #######       ##      ### ###  ##   ##  ##  ###  ##   ##   ##       
                 ########  ##      ###  ###      ##      ### ##   ###  ##  ##  ##   ###  ##   ###      
                 #######   ##            ##      ##      ### ##    ##  ##  ##  ##    ##  ########      
                 ##        ##            ##      ###     ##  ##    ##  ##  ##  ##    ##  ##            
                 ##        ##      ###   ##      ###    ###  ##    ##  ##  ##  ##    ##  ##    #       
                 ##        ##      ########       ########   ##    ##  ##  ##  ##    ##  #######       
                 ##        ##       ######         ######    ##    ##  ##  ##  ##    ##   #####        
            """
        }
    }

    // MARK: - SF Pro Rounded Bold Tests

    func testSnapshotSFProRoundedBoldPreview() throws {
        guard let path = getSFProRoundedFontPath() else { return }
        let converter = try XCTUnwrap(FontConverter(fontPath: path, size: 18, threshold: 170))

        let preview = converter.previewString(text: "Rounded 18")
        assertInlineSnapshot(of: preview, as: .lines) {
            """
                 ########                                        ###                  ###        ####     ######         
                 #########                                       ###                  ###       #####    ########        
                 ###  #####                                      ###                  ###      ######   ####  ####       
                 ###    ###    #####   ##    ##  ## ####    #### ###    ####     #### ###     ### ###   ###   ####       
                 ###    ###  ########  ###   ### ########  #########  ########  #########         ###   ####  ###        
                 ###   ####  #### #### ###   ### ######### #########  ########  #########         ###    ########        
                 #########  ####   ### ###   ### ###  ########   ### ####  ########   ###         ###    #######         
                 ########   ####   ### ###   ### ###   #######   ### ##############   ###         ###   ##########       
                 ###  ###   ###    ### ###   ### ###   #######   ### ######### ####   ###         ###   ###    ###       
                 ###  ####  ####   ### ###  #### ###   #######   ### ####    # ####   ###         ###  ####    ###       
                 ###   ####  ###  #### ######### ###   ### #### ####  ###  ###  #### ####         ###   ####  ####       
                 ###   ####  ########  ######### ###   ### #########  ########  #########         ###   ##########       
                 ###    ###   ######    #### ### ##    ###  ########   ######    ########         ###    #######         
            """
        }
    }

    // MARK: - Monaco Tests

    func testSnapshotMonacoAsciiArtPreview() throws {
        guard let path = getMonacoFontPath() else { return }
        let converter = try XCTUnwrap(FontConverter(fontPath: path, size: 24, threshold: 170))

        let preview = converter.previewString(text: "CPU: 34%")
        assertInlineSnapshot(of: preview, as: .lines) {
            """
                      ######    #######       ##       ##                               ########            ##       #        ###     
                    #########   #########    ###      ###                               #########          ####    #####     ###      
                   #####  ###   ##########   ###      ###                               ###   ####         ####   #######    ##       
                   ###          ###    ####  ###      ###                                      ###        #####   ###  ##   ###       
                  ####          ###     ###  ###      ###                                      ###       ######   ##   ### ###        
                  ###           ###      ### ###      ###       ##                             ###       ######   ##   ### ##         
                 ####           ###     #### ###      ###      ####                           ####      ### ###   ##   ## ###         
                 ####           ###     ###  ###      ###      ####                         #####      ###  ###   ###  #####          
                 ###            ###     ###  ###      ###      ####                      #######       ###  ###    ########           
                 ###            ###   ####   ###      ###                                ########     ###   ###     #######           
                 ###            #########    ###      ###                                     ####   ###    ###        ########       
                 ###            ########     ###      ###                                      #### ####    ###        #########      
                 ####           ####         ###      ###                                       ### ##############    ######  ##      
                  ###           ###          ###      ###                                       ### ##############   ### ##   ###     
                  ###           ###          ###      ###                                       ###         ###      ### ##   ###     
                  ####          ###          ####     ###        #                              ###         ###     ###  ###  ##      
                   ####     #   ###           ###    ###       ####                    ##      ###          ###     ##   ###  ##      
                    #########   ###           ##########       ####                    ###########          ###    ###    ######      
                     ########   ###            ########        ####                     ########            ###   ###      ####       
                       ###                        ##             #                        ####                    ##                  
            """
        }
    }

    // MARK: - Courier New Tests

    func testSnapshotCourierNewFixedGlyphDump() throws {
        guard let path = getCourierFontPath() else { return }
        let converter = try XCTUnwrap(FontConverter(fontPath: path, size: 14, threshold: 170))

        let glyphAt = converter.extractFixedGlyph("@", cellWidth: 9)
        assertInlineSnapshot(of: glyphAt, as: .dump) {
            """
            ▿ FixedGlyphData
              ▿ bytes: 32 elements
                - 0
                - 0
                - 0
                - 0
                - 28
                - 0
                - 36
                - 0
                - 98
                - 0
                - 78
                - 0
                - 90
                - 0
                - 82
                - 0
                - 78
                - 0
                - 96
                - 0
                - 32
                - 0
                - 28
                - 0
                - 0
                - 0
                - 0
                - 0
                - 0
                - 0
                - 0
                - 0

            """
        }
    }

    // MARK: - SF Pro Display Heavy Tests

    func testSnapshotSFProDisplayHeavyPreview() throws {
        guard let path = getSFProDisplayHeavyFontPath() else { return }
        let converter = try XCTUnwrap(FontConverter(fontPath: path, size: 22, threshold: 170))

        let preview = converter.previewString(text: "COUNT: 42")
        assertInlineSnapshot(of: preview, as: .lines) {
            """
                     #######         #######      ####     #####  ####      #### #############                ######       ######          
                   ##########      ##########     ####     #####  #####    ##### #############                ######     ##########        
                  ############    #############   ####     #####  #####    ##### #############               #######    ###########        
                  #############   #############   ####     #####  ######   ##### #############              ########    ############       
                 #####    #####  #####    ######  ####     #####  #######  #####     #####                  ########    ####   #####       
                 #####     ####  #####     #####  ####     #####  #######  #####     #####     ####        #### ####    ###    #####       
                 ####       ###  ####       ####  ####     #####  ######## #####     #####     ####        #### ####           #####       
                 ####            ####       ####  ####     #####  ##############     #####     ####       ####  ####          #####        
                #####           #####       ####  ####     #####  #### #########     #####     ###       ####   ####         #####         
                 ####            ####       ####  ####     #####  ####  ########     #####               ####   ####        #####          
                 #####     ##### #####     #####  #####    #####  ####  ########     #####              ##############     #####           
                 #####    #####  #####     #####  #####    #####  ####   #######     #####              ##############   ######            
                 ##############   ###### ######   ###### ######   ####    ######     #####     ###      ##############  ######             
                  ############    #############    ############   ####    ######     #####     ####      #############  ############       
                   ###########     ###########      ##########    ####     #####     #####     ####             ####    ############       
                    ########         #######         ########     ####      ####     #####     ###              ####    ############       
            """
        }
    }
}
