import AppKit
import ServiceManagement
import SwiftUI
import UserNotifications

@main
struct ReagentrApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene { Settings { EmptyView() } }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ note: Notification) {
        let controller = AppController.shared
        statusItem = StatusItemController(controller: controller)
        controller.start()
        UNUserNotificationCenter.current().delegate = self
        if SMAppService.mainApp.status == .notRegistered { try? SMAppService.mainApp.register() }
    }

    // reagentr://open from the widget.
    func application(_ application: NSApplication, open urls: [URL]) {
        if urls.contains(where: { $0.scheme == "reagentr" }) { statusItem?.show() }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        await MainActor.run { statusItem?.show() }
    }
}
