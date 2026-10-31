import AppKit
import ReagentrKit
import SwiftUI
import WidgetKit

// Renders the real popover and widget views with sample data so design changes can be reviewed as images.
let out = URL(fileURLWithPath: CommandLine.arguments.dropFirst().first ?? "/tmp/reagentr-shots")
try? FileManager.default.createDirectory(at: out, withIntermediateDirectories: true)
_ = NSApplication.shared

@MainActor func render<V: View>(_ view: V, size: CGSize, dark: Bool, name: String) {
    let host = NSHostingView(rootView: view)
    host.frame = CGRect(origin: .zero, size: size)
    let window = NSWindow(contentRect: host.frame, styleMask: [.borderless], backing: .buffered, defer: false)
    window.appearance = NSAppearance(named: dark ? .darkAqua : .aqua)
    window.contentView = host
    host.layoutSubtreeIfNeeded()
    RunLoop.main.run(until: Date().addingTimeInterval(0.8)) // let onAppear springs settle
    let rep = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: Int(size.width * 2), pixelsHigh: Int(size.height * 2),
                               bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
                               colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0)!
    rep.size = size
    host.cacheDisplay(in: host.bounds, to: rep)
    try! rep.representation(using: .png, properties: [:])!.write(to: out.appendingPathComponent("\(name)-\(dark ? "dark" : "light").png"))
}

func sampleStore(empty: Bool) -> URL {
    let url = FileManager.default.temporaryDirectory.appendingPathComponent("reagentr-snap-\(UUID().uuidString)/todos.json")
    let cal = Calendar.autoupdatingCurrent
    let today = LocalDate(Date(), calendar: cal)
    func mk(_ title: String, _ offset: Int?, _ time: String?, _ source: String, done: Bool = false) -> Todo {
        Todo(id: Todo.newID(avoiding: []), title: title, date: offset.map { today.adding(days: $0, calendar: cal) },
             time: time.flatMap(LocalTime.init), source: source, createdAt: Date(), completedAt: done ? Date() : nil)
    }
    let todos = empty ? [mk("Ship the onboarding copy", 2, nil, "Claude")] : [
        mk("Call the bank about the card", -1, nil, "Claude"),
        mk("Review the widget PR", 0, "11:30", "Codex"),
        mk("Renew the domain", 0, "17:00", "Claude"),
        mk("Buy oat milk", nil, nil, "you"),
        mk("Reply to Maya about Friday", 0, nil, "you"),
        mk("Ship the onboarding copy", 2, nil, "Claude"),
        mk("Send invoice to Acme", 6, "10:00", "Codex"),
        mk("Water the plants", nil, nil, "you", done: true),
    ]
    try! TodoStore(url: url).mutate { $0 = todos }
    return url
}

MainActor.assumeIsolated {
    let desktop = Color(nsColor: NSColor(white: 0.55, alpha: 1))
    for empty in [false, true] {
        let url = sampleStore(empty: empty)
        let app = AppController(storeURL: url)
        app.reload()
        let entry = Provider(storeURL: url).entries(now: Date()).first!
        for dark in [false, true] {
            let tag = empty ? "-empty" : ""
            render(PopoverRoot().environment(app)
                    .background(Color(nsColor: .windowBackgroundColor))
                    .environment(\.colorScheme, dark ? .dark : .light),
                   size: CGSize(width: 340, height: empty ? 260 : 470), dark: dark, name: "popover\(tag)")
            if !empty {
                render(QuickAdd(title: "Pay rent").environment(app).padding(8)
                        .background(Color(nsColor: .windowBackgroundColor))
                        .environment(\.colorScheme, dark ? .dark : .light),
                       size: CGSize(width: 340, height: 90), dark: dark, name: "quickadd")
            }
            for (family, size, name) in [(WidgetFamily.systemSmall, CGSize(width: 170, height: 170), "small"),
                                         (.systemMedium, CGSize(width: 364, height: 170), "medium"),
                                         (.systemLarge, CGSize(width: 364, height: 382), "large")] {
                let widget = WidgetBody(entry: entry, family: family)
                    .padding(16)
                    .frame(width: size.width, height: size.height)
                    .background(Color(nsColor: .textBackgroundColor), in: .rect(cornerRadius: 22, style: .continuous))
                    .padding(24)
                    .background(desktop)
                    .environment(\.colorScheme, dark ? .dark : .light)
                render(widget, size: CGSize(width: size.width + 48, height: size.height + 48), dark: dark, name: "widget-\(name)\(tag)")
            }
        }
    }
    print("Wrote snapshots to \(out.path)")
}
