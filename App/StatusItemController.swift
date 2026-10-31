import AppKit
import Observation
import SwiftUI

/// Menu bar item + popover. AppKit-hosted so the widget (remy://open) and notifications can open it programmatically.
@MainActor
final class StatusItemController: NSObject {
    private let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let controller: AppController

    init(controller: AppController) {
        self.controller = controller
        super.init()
        popover.behavior = .transient
        popover.animates = true
        popover.contentViewController = NSHostingController(rootView: PopoverRoot().environment(controller))
        if let button = item.button {
            button.image = Self.remyGlyph
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(toggle)
        }
        observeCount()
    }

    /// Remy's head as a menu bar template image: dome with eye and smile cut-outs (tints with the menu bar).
    static let remyGlyph: NSImage = {
        let image = NSImage(size: NSSize(width: 18, height: 18), flipped: false) { _ in
            let head = NSBezierPath()
            head.move(to: NSPoint(x: 1, y: 4.5))
            head.appendArc(withCenter: NSPoint(x: 9, y: 4.5), radius: 8, startAngle: 180, endAngle: 0, clockwise: true)
            head.close()
            NSColor.black.setFill()
            head.fill()
            NSGraphicsContext.current?.compositingOperation = .clear
            NSBezierPath(ovalIn: NSRect(x: 5.2, y: 7.6, width: 3.0, height: 3.0)).fill()
            NSBezierPath(ovalIn: NSRect(x: 9.8, y: 7.6, width: 3.0, height: 3.0)).fill()
            let smile = NSBezierPath()
            smile.move(to: NSPoint(x: 7.3, y: 6.3))
            smile.curve(to: NSPoint(x: 10.7, y: 6.3), controlPoint1: NSPoint(x: 8.1, y: 5.3), controlPoint2: NSPoint(x: 9.9, y: 5.3))
            smile.lineWidth = 1.1
            smile.lineCapStyle = .round
            smile.stroke()
            return true
        }
        image.isTemplate = true
        image.accessibilityDescription = "Remy"
        return image
    }()

    @objc private func toggle() { popover.isShown ? popover.performClose(nil) : show() }

    func show() {
        guard let button = item.button, !popover.isShown else { return }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        popover.contentViewController?.view.window?.makeKey()
        NSApp.activate()
    }

    /// Keep the menu bar count in sync with today's open items.
    private func observeCount() {
        withObservationTracking {
            let n = controller.visible.count
            item.button?.title = n > 0 ? " \(n)" : ""
        } onChange: { [weak self] in
            Task { @MainActor in self?.observeCount() }
        }
    }
}
