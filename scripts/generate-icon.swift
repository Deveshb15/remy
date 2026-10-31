#!/usr/bin/env swift
// Remy app icon ("Peek": Remy peeks up from the bottom edge, googly eyes glancing up, smile, blush).
// Writes the Icon Composer layer masks (black on transparent, 1024 canvas) into the .icon bundle given as arg 1.
// Colours live in App/AppIcon.icon/icon.json so light/dark appearances only swap fills. Master: design/logo/final/remy-icon.svg.
import AppKit
import CoreGraphics

let S: CGFloat = 1024
let iconDir = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "App/AppIcon.icon")
let assets = iconDir.appendingPathComponent("Assets")
try? FileManager.default.createDirectory(at: assets, withIntermediateDirectories: true)

/// Coordinates are taken from the 256-unit SVG master (y down) and scaled 4×; CG's y axis points up.
func p(_ x: CGFloat, _ y: CGFloat) -> CGPoint { CGPoint(x: x * 4, y: S - y * 4) }

func layer(_ name: String, _ draw: (CGContext) -> Void) {
    let ctx = CGContext(data: nil, width: Int(S), height: Int(S), bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.setFillColor(CGColor(gray: 0, alpha: 1))
    ctx.setStrokeColor(CGColor(gray: 0, alpha: 1))
    draw(ctx)
    let rep = NSBitmapImageRep(cgImage: ctx.makeImage()!)
    try! rep.representation(using: .png, properties: [:])!.write(to: assets.appendingPathComponent("\(name).png"))
}

func circle(_ c: CGContext, _ cx: CGFloat, _ cy: CGFloat, _ r: CGFloat) {
    let o = p(cx, cy)
    c.fillEllipse(in: CGRect(x: o.x - r * 4, y: o.y - r * 4, width: r * 8, height: r * 8))
}

// Head: half-disc r=98 centred (128,226), continued to the bottom edge.
layer("head") { c in
    c.move(to: p(30, 256)); c.addLine(to: p(30, 226))
    c.addArc(center: p(128, 226), radius: 98 * 4, startAngle: .pi, endAngle: 0, clockwise: true)
    c.addLine(to: p(226, 256)); c.closePath(); c.fillPath()
}
layer("eyes") { c in circle(c, 106, 182, 19); circle(c, 150, 182, 19) }          // sclera
layer("pupils") { c in circle(c, 111, 176, 8.9); circle(c, 155, 176, 8.9) }      // glancing up and right
layer("smile") { c in
    c.setLineWidth(7 * 4); c.setLineCap(.round)
    c.move(to: p(114, 214)); c.addQuadCurve(to: p(142, 214), control: p(128, 226)); c.strokePath()
}
layer("blush") { c in
    for x in [72.0, 184.0] {
        let o = p(x, 206)
        c.fillEllipse(in: CGRect(x: o.x - 44, y: o.y - 26, width: 88, height: 52))
    }
}
print("Wrote layers to \(assets.path)")
