#!/usr/bin/env python3
"""
TrueType / OpenType Font Converter for e-Paper Display (Swift)

Converts any .ttf or .otf font into pure Swift code compatible with:
1. ProportionalFont: Proportional spacing, individual glyph bounding boxes (SF Pro, Inter, etc.)
2. BitmapFont: Fixed-width monospace matrix (Fira Code, JetBrains Mono, etc.)

Requires Python 3 and Pillow (PIL):
    pip install Pillow
"""

import argparse
import os
import sys
from PIL import Image, ImageFont, ImageDraw

def render_terminal_preview(font, text, threshold=170):
    """Renders a sample text string as ASCII art in the terminal."""
    left, top, right, bottom = font.getbbox(text)
    w = max(1, right - left)
    h = max(1, bottom - top)
    margin = 2
    img = Image.new('L', (w + margin * 2, h + margin * 2), 255)
    draw = ImageDraw.Draw(img)
    draw.text((-left + margin, -top + margin), text, font=font, fill=0)
    b_img = img.point(lambda p: 0 if p < threshold else 255, mode='1')

    print("\n" + "=" * 60)
    print(f" Terminal Preview for: \"{text}\" (Threshold: {threshold})")
    print("=" * 60)
    for y in range(b_img.height):
        row = ''.join('#' if b_img.getpixel((x, y)) == 0 else ' ' for x in range(b_img.width))
        if '#' in row:
            print(row)
    print("=" * 60 + "\n")

def convert_proportional(font, font_name, threshold=170, ascii_start=32, ascii_end=126):
    """Converts font into ProportionalFont Swift definition."""
    ascent, descent = font.getmetrics()
    line_height = ascent + descent
    glyph_lines = []

    for code in range(ascii_start, ascii_end + 1):
        ch = chr(code)
        adv = int(round(font.getlength(ch)))
        if ch == ' ':
            glyph_lines.append(f"            ProportionalGlyph(advance: {adv}, width: 0, height: 0, left: 0, top: 0, bytes: []), // ' ' (32)")
            continue

        left, top, right, bottom = font.getbbox(ch)
        w = max(0, right - left)
        h = max(0, bottom - top)
        if w == 0 or h == 0:
            glyph_lines.append(f"            ProportionalGlyph(advance: {adv}, width: 0, height: 0, left: 0, top: 0, bytes: []), // '{ch}' ({code})")
            continue

        margin = 2
        img = Image.new('L', (w + margin * 2, h + margin * 2), 255)
        d = ImageDraw.Draw(img)
        d.text((-left + margin, -top + margin), ch, font=font, fill=0)
        b_img = img.point(lambda p: 0 if p < threshold else 255, mode='1')

        bbox = b_img.getbbox()
        if not bbox:
            glyph_lines.append(f"            ProportionalGlyph(advance: {adv}, width: 0, height: 0, left: 0, top: 0, bytes: []), // '{ch}' ({code})")
            continue

        bx0, by0, bx1, by1 = bbox
        bw = bx1 - bx0
        bh = by1 - by0
        b_left = left + (bx0 - margin)
        b_top = top + (by0 - margin)

        bytes_list = []
        bpr = (bw + 7) // 8
        for y in range(by0, by1):
            byte_val = 0
            bit_idx = 7
            for x in range(bx0, bx1):
                if b_img.getpixel((x, y)) == 0:
                    byte_val |= (1 << bit_idx)
                bit_idx -= 1
                if bit_idx < 0:
                    bytes_list.append(byte_val)
                    byte_val = 0
                    bit_idx = 7
            if bit_idx != 7:
                bytes_list.append(byte_val)

        ch_desc = ch
        if ch_desc == '\\':
            ch_desc = '\\\\'
        elif ch_desc == '"':
            ch_desc = '\\"'
        b_str = ', '.join(f"0x{b:02X}" for b in bytes_list)
        glyph_lines.append(f"            ProportionalGlyph(advance: {adv}, width: {bw}, height: {bh}, left: {b_left}, top: {b_top}, bytes: [{b_str}]), // '{ch_desc}' ({code})")

    code = f"""    public static let {font_name} = ProportionalFont(
        name: "{font_name}",
        lineHeight: {line_height},
        glyphs: [
{chr(10).join(glyph_lines)}
        ]
    )
"""
    return code

def convert_fixed(font, font_name, threshold=170, ascii_start=32, ascii_end=126):
    """Converts font into monospace BitmapFont Swift definition."""
    ascent, descent = font.getmetrics()
    cell_h = ascent + descent
    max_w = int(round(max(font.getlength(chr(c)) for c in range(ascii_start, ascii_end + 1))))
    bytes_per_row = (max_w + 7) // 8
    glyph_lines = []

    for code in range(ascii_start, ascii_end + 1):
        ch = chr(code)
        img = Image.new('L', (max_w, cell_h), 255)
        d = ImageDraw.Draw(img)
        d.text((0, 0), ch, font=font, fill=0)
        b_img = img.point(lambda p: 0 if p < threshold else 255, mode='1')

        bytes_list = []
        for y in range(cell_h):
            byte_val = 0
            bit_idx = 7
            for x in range(max_w):
                if b_img.getpixel((x, y)) == 0:
                    byte_val |= (1 << bit_idx)
                bit_idx -= 1
                if bit_idx < 0:
                    bytes_list.append(byte_val)
                    byte_val = 0
                    bit_idx = 7
            if bit_idx != 7:
                bytes_list.append(byte_val)

        ch_desc = ch
        if ch_desc == '\\':
            ch_desc = '\\\\'
        elif ch_desc == '"':
            ch_desc = '\\"'
        b_str = ', '.join(f"0x{b:02X}" for b in bytes_list)
        glyph_lines.append(f"            [{b_str}], // '{ch_desc}' ({code})")

    code = f"""    public static let {font_name} = BitmapFont(
        name: "{font_name}",
        width: {max_w},
        height: {cell_h},
        bytesPerRow: {bytes_per_row},
        glyphs: [
{chr(10).join(glyph_lines)}
        ]
    )
"""
    return code

def main():
    parser = argparse.ArgumentParser(
        description="Convert TrueType (.ttf) or OpenType (.otf) fonts to Swift 1-bit e-Paper code."
    )
    parser.add_argument("font_path", help="Path to TTF or OTF font file.")
    parser.add_argument("-s", "--size", type=int, default=16, help="Font point size (default: 16).")
    parser.add_argument("-n", "--name", help="Swift variable name (default: derived from filename + size).")
    parser.add_argument(
        "-t", "--type", choices=["proportional", "fixed"], default="proportional",
        help="Font type: 'proportional' for variable width (SF Pro, Inter), 'fixed' for monospace (default: proportional)."
    )
    parser.add_argument(
        "--threshold", type=int, default=170,
        help="Binarization threshold 0-255 (default: 170). Higher = thicker/bolder strokes on e-Paper."
    )
    parser.add_argument("-o", "--output", help="Output .swift file. If omitted, writes to stdout.")
    parser.add_argument(
        "-p", "--preview", nargs="?", const="RPi 5 Ready! 123",
        help="Preview rendered ASCII art in the terminal (optional custom string)."
    )

    args = parser.parse_args()

    if not os.path.exists(args.font_path):
        print(f"Error: Font file '{args.font_path}' does not exist.", file=sys.stderr)
        sys.exit(1)

    try:
        font = ImageFont.truetype(args.font_path, args.size)
    except Exception as e:
        print(f"Error loading font '{args.font_path}': {e}", file=sys.stderr)
        sys.exit(1)

    # Derive Swift property name
    if args.name:
        font_name = args.name
    else:
        base = os.path.splitext(os.path.basename(args.font_path))[0]
        # Clean non-alphanumeric chars
        cleaned = ''.join(c if c.isalnum() else '_' for c in base)
        font_name = f"{cleaned.lower()}_{args.size}pt"

    # Terminal preview if requested
    if args.preview:
        render_terminal_preview(font, args.preview, threshold=args.threshold)

    # Convert font
    if args.type == "proportional":
        font_code = convert_proportional(font, font_name, threshold=args.threshold)
        ext_type = "ProportionalFont"
    else:
        font_code = convert_fixed(font, font_name, threshold=args.threshold)
        ext_type = "BitmapFont"

    full_output = f"""//
//  Generated by convert_font.py
//  Source: {os.path.basename(args.font_path)} ({args.size}pt)
//

import Foundation

extension {ext_type} {{
{font_code}}}
"""

    if args.output:
        with open(args.output, "w") as f:
            f.write(full_output)
        print(f"Successfully generated Swift font '{font_name}' in: {args.output}")
    else:
        print(full_output)

if __name__ == "__main__":
    main()
