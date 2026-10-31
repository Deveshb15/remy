#!/usr/bin/env swift
// Remy app icon: the filled check disc from the UI (CheckGlyph), on a soft neutral field.
// Drawn on Apple's macOS icon template (rounded square with transparent margin); no baked shine/shadow.
// Writes icon-variants/{a,b,c}-{light,dark,tinted}.png at 1024px. Shipped: a-light (see App/Assets.xcassets).
import AppKit
import CoreGraphics

let S: CGFloat = 1024
let outDir = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "icon-variants")
try? FileManager.default.createDirectory(at: outDir, withIntermediateDirectories: true)

func gray(_ w: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(gray: w, alpha: a) }

struct Palette { let top, bottom, mark, knock: CGColor }
let palettes: [String: Palette] = [
    "light": Palette(top: gray(0.99), bottom: gray(0.90), mark: gray(0.11), knock: gray(0.99)),
    "dark": Palette(top: gray(0.22), bottom: gray(0.10), mark: gray(0.96), knock: gray(0.12)),
    "tinted": Palette(top: gray(0.30), bottom: gray(0.18), mark: gray(1.0), knock: gray(0.24)),
]

/// macOS icon template: an 824pt rounded square centered on the 1024 canvas, transparent outside.
/// Art that matches this shape is shown as-is on macOS 26; anything else gets boxed in a gray "legacy" frame.
let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
let tileRadius: CGFloat = 185.4

func background(_ c: CGContext, _ p: Palette) {
    c.addPath(CGPath(roundedRect: tile, cornerWidth: tileRadius, cornerHeight: tileRadius, transform: nil))
    c.clip()
    let g = CGGradient(colorsSpace: CGColorSpace(name: CGColorSpace.genericGrayGamma2_2), colors: [p.top, p.bottom] as CFArray, locations: [0, 1])!
    c.drawLinearGradient(g, start: CGPoint(x: 0, y: tile.maxY), end: CGPoint(x: 0, y: tile.minY), options: [])
}

/// Rounded check inside a circle of radius r centered at (cx, cy).
func check(_ c: CGContext, cx: CGFloat, cy: CGFloat, r: CGFloat, color: CGColor, width: CGFloat) {
    c.setStrokeColor(color)
    c.setLineWidth(width)
    c.setLineCap(.round)
    c.setLineJoin(.round)
    c.move(to: CGPoint(x: cx - 0.40 * r, y: cy + 0.02 * r))
    c.addLine(to: CGPoint(x: cx - 0.12 * r, y: cy - 0.27 * r))
    c.addLine(to: CGPoint(x: cx + 0.42 * r, y: cy + 0.30 * r))
    c.strokePath()
}

// A: solid disc with a knocked-out check (the "done" state from the app).
func variantA(_ c: CGContext, _ p: Palette) {
    background(c, p)
    let r: CGFloat = 205
    c.setFillColor(p.mark)
    c.fillEllipse(in: CGRect(x: S / 2 - r, y: S / 2 - r, width: 2 * r, height: 2 * r))
    check(c, cx: S / 2, cy: S / 2, r: r, color: p.knock, width: 0.17 * r)
}

// B: open ring with the check drawn through it (the moment of checking off).
func variantB(_ c: CGContext, _ p: Palette) {
    background(c, p)
    let r: CGFloat = 255
    c.setStrokeColor(p.mark)
    c.setLineWidth(44)
    c.strokeEllipse(in: CGRect(x: S / 2 - r, y: S / 2 - r, width: 2 * r, height: 2 * r))
    check(c, cx: S / 2, cy: S / 2, r: r, color: p.mark, width: 0.19 * r)
}

// C: a stack of to-do rows, the top one checked (the widget, distilled).
func variantC(_ c: CGContext, _ p: Palette) {
    background(c, p)
    let r: CGFloat = 74, x0: CGFloat = 250, lineX: CGFloat = 380
    for (i, y) in [650.0, 512.0, 374.0].enumerated() {
        let cy = CGFloat(y)
        if i == 0 {
            c.setFillColor(p.mark)
            c.fillEllipse(in: CGRect(x: x0 - r, y: cy - r, width: 2 * r, height: 2 * r))
            check(c, cx: x0, cy: cy, r: r, color: p.knock, width: 0.24 * r)
        } else {
            c.setStrokeColor(p.mark.copy(alpha: 0.45)!)
            c.setLineWidth(18)
            c.strokeEllipse(in: CGRect(x: x0 - r + 9, y: cy - r + 9, width: 2 * r - 18, height: 2 * r - 18))
        }
        c.setFillColor(p.mark.copy(alpha: i == 0 ? 1 : 0.45)!)
        let w: CGFloat = i == 0 ? 400 : (i == 1 ? 330 : 370)
        c.addPath(CGPath(roundedRect: CGRect(x: lineX, y: cy - 22, width: w, height: 44), cornerWidth: 22, cornerHeight: 22, transform: nil))
        c.fillPath()
    }
}

let variants: [(String, (CGContext, Palette) -> Void)] = [("a", variantA), ("b", variantB), ("c", variantC)]
for (name, draw) in variants {
    for (mode, p) in palettes {
        let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                            space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
        draw(ctx, p)
        let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
        try! rep.representation(using: .png, properties: [:])!.write(to: outDir.appendingPathComponent("\(name)-\(mode).png"))
    }
}
// Icon Composer layer: the disc with the check cut out (transparent), on a transparent 1024 canvas.
// The .icon's background fill shows through the cut, so light/dark only need fill colors swapped.
do {
    let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    let r: CGFloat = 262
    ctx.setFillColor(gray(0))
    ctx.fillEllipse(in: CGRect(x: S / 2 - r, y: S / 2 - r, width: 2 * r, height: 2 * r))
    ctx.setBlendMode(.clear)
    check(ctx, cx: S / 2, cy: S / 2, r: r, color: gray(0), width: 0.17 * r)
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: outDir.appendingPathComponent("disc.png"))
}
print("Wrote variants to \(outDir.path)")
