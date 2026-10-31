import AppKit
import ServiceManagement
import SwiftUI
import UserNotifications

@main
struct RemyApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate
    var body: some Scene { Settings { EmptyView() } }
}

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate, UNUserNotificationCenterDelegate {
    private var statusItem: StatusItemController?

    func applicationDidFinishLaunching(_ note: Notification) {
        let controller = AppController.shared
        statusItem = StatusItemController(controller: controller)
        _ = Updater.shared // starts scheduled update checks
        controller.start()
        UNUserNotificationCenter.current().delegate = self
        if SMAppService.mainApp.status == .notRegistered { try? SMAppService.mainApp.register() }
        if !OnboardingModel.isOnboarded || CommandLine.arguments.contains("--onboarding") || Installer.needsMove {
            OnboardingWindow.shared.show()
        }
        if !Installer.needsMove { Task { await Installer.repairAll() } }
    }

    // remy://open from the widget.
    // remy://open (widget click), remy://connect and remy://widget (jump into onboarding).
    func application(_ application: NSApplication, open urls: [URL]) {
        for url in urls where url.scheme == "remy" {
            switch url.host {
            case "connect": OnboardingWindow.shared.show(at: .connect)
            case "widget": OnboardingWindow.shared.show(at: .widget)
            default: statusItem?.show()
            }
        }
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification) async -> UNNotificationPresentationOptions {
        [.banner, .sound]
    }

    nonisolated func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse) async {
        let isUpdate = response.notification.request.identifier == Updater.notificationID
        await MainActor.run { isUpdate ? Updater.shared.checkForUpdates() : statusItem?.show() }
    }

    /// Target of the popover's "Check for Updates…" (sent up the responder chain, so the UI doesn't import Sparkle).
    @objc func checkForUpdates(_ sender: Any?) { Updater.shared.checkForUpdates() }
}
