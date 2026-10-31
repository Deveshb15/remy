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
            button.image = NSImage(systemSymbolName: "checklist", accessibilityDescription: "Remy")
            button.imagePosition = .imageLeading
            button.target = self
            button.action = #selector(toggle)
        }
        observeCount()
    }

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
