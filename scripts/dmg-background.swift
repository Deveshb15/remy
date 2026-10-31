// Renders the DMG window background (1x + 2x PNG) into the directory given as the first argument.
// Layout must match scripts/dmg-settings.py: 600x380 window, icons centered at (170,170) and (430,170).
import AppKit
import SwiftUI

let out = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "build")

struct Background: View {
    var body: some View {
        ZStack {
            LinearGradient(colors: [Color(white: 0.985), Color(white: 0.955)], startPoint: .top, endPoint: .bottom)
            // A soft, slightly arched arrow from the app to Applications.
            Path { p in
                p.move(to: CGPoint(x: 252, y: 176))
                p.addQuadCurve(to: CGPoint(x: 346, y: 176), control: CGPoint(x: 299, y: 146))
            }
            .stroke(Color(white: 0.72), style: StrokeStyle(lineWidth: 2.2, lineCap: .round))
            Path { p in
                // Head follows the curve's tangent at the tip (control -> end), opened ±30°.
                p.move(to: CGPoint(x: 340.9, y: 166.2))
                p.addLine(to: CGPoint(x: 346, y: 176))
                p.addLine(to: CGPoint(x: 335, y: 175.5))
            }
            .stroke(Color(white: 0.72), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
            Text("Drag Remy to Applications")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(Color(white: 0.55))
                .position(x: 300, y: 292) // clear of Finder's path bar when the user has it on
        }
        .frame(width: 600, height: 380)
    }
}

MainActor.assumeIsolated {
    for scale in [1.0, 2.0] {
        let r = ImageRenderer(content: Background())
        r.scale = scale
        let rep = NSBitmapImageRep(cgImage: r.cgImage!)
        let name = scale == 1 ? "dmg-background.png" : "dmg-background@2x.png"
        try! rep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent(name))
    }
}
