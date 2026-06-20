import AppKit
import SwiftUI

enum AppEnvironment {
    static let fanStore = FanStore(service: SMCFanService())
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBarController: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let controller = StatusBarController(store: AppEnvironment.fanStore)
        statusBarController = controller

        DispatchQueue.main.async {
            controller.showControlWindow()
        }
    }

    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        statusBarController?.showControlWindow()
        return false
    }
}

@main
struct MacFanApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var appDelegate

    var body: some Scene {
        Settings {
            EmptyView()
        }
    }
}
