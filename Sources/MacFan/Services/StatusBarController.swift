import AppKit
import Combine
import SwiftUI

final class StatusBarController: NSObject {
    private let store: FanStore
    private let statusItem: NSStatusItem
    private let panel: NSPanel
    private var controlWindow: NSWindow?
    private var eventMonitor: Any?
    private var cancellables = Set<AnyCancellable>()

    init(store: FanStore) {
        self.store = store
        self.statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        self.panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 380, height: 500),
            styleMask: [.nonactivatingPanel, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )

        super.init()

        configureStatusItem()
        configurePanel()
        bindStore()
        updateStatusItem()
        store.refresh()
    }

    deinit {
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
        }
    }

    @objc private func togglePanel(_ sender: Any?) {
        panel.isVisible ? closePanel() : showPanel()
    }

    private func configureStatusItem() {
        guard let button = statusItem.button else { return }

        button.target = self
        button.action = #selector(togglePanel(_:))
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        button.title = ""
        button.toolTip = "MacFan"
        button.imagePosition = .imageLeading
        button.image = NSImage(systemSymbolName: "fanblades", accessibilityDescription: "MacFan")
    }

    private func configurePanel() {
        panel.isReleasedWhenClosed = false
        panel.isFloatingPanel = true
        panel.hidesOnDeactivate = false
        panel.level = .popUpMenu
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]
        panel.titleVisibility = .hidden
        panel.titlebarAppearsTransparent = true

        let content = StatusPanelContentView(openWindow: { [weak self] in
            self?.showControlWindow()
        })
        .environmentObject(store)

        panel.contentViewController = NSHostingController(rootView: content)
    }

    private func bindStore() {
        store.$fans
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusItem() }
            .store(in: &cancellables)

        store.$errorMessage
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusItem() }
            .store(in: &cancellables)

        store.$lastUpdated
            .receive(on: RunLoop.main)
            .sink { [weak self] _ in self?.updateStatusItem() }
            .store(in: &cancellables)
    }

    private func updateStatusItem() {
        guard let button = statusItem.button else { return }

        button.title = ""
        button.toolTip = "MacFan - \(store.menuBarTitle)"
        button.contentTintColor = store.errorMessage == nil ? nil : .systemOrange
        statusItem.length = NSStatusItem.squareLength
    }

    private func showPanel() {
        guard let button = statusItem.button,
              let buttonWindow = button.window,
              let screen = buttonWindow.screen ?? NSScreen.main else {
            return
        }

        store.refresh()

        let buttonRect = buttonWindow.convertToScreen(button.frame)
        let visibleFrame = screen.visibleFrame
        let panelSize = panel.frame.size
        let x = (buttonRect.midX - panelSize.width / 2)
            .clamped(to: visibleFrame.minX + 8...visibleFrame.maxX - panelSize.width - 8)
        let y = buttonRect.minY - panelSize.height - 8

        panel.setFrameOrigin(NSPoint(x: x, y: y))
        panel.orderFrontRegardless()
        installEventMonitor()
    }

    private func closePanel() {
        panel.orderOut(nil)
        if let eventMonitor {
            NSEvent.removeMonitor(eventMonitor)
            self.eventMonitor = nil
        }
    }

    private func installEventMonitor() {
        guard eventMonitor == nil else { return }

        eventMonitor = NSEvent.addGlobalMonitorForEvents(matching: [.leftMouseDown, .rightMouseDown]) { [weak self] _ in
            self?.closePanel()
        }
    }

    private func showControlWindow() {
        closePanel()

        let window: NSWindow
        if let existingWindow = controlWindow {
            window = existingWindow
        } else {
            let hostingController = NSHostingController(
                rootView: ControlWindowView()
                    .environmentObject(store)
            )

            window = NSWindow(contentViewController: hostingController)
            window.title = "MacFan"
            window.styleMask = [.titled, .closable, .miniaturizable, .resizable]
            window.setContentSize(NSSize(width: 440, height: 560))
            window.isReleasedWhenClosed = false
            window.center()
            controlWindow = window
        }

        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
}

private struct StatusPanelContentView: View {
    let openWindow: () -> Void

    var body: some View {
        ControlPanelView(compact: true, openWindow: openWindow)
            .frame(width: 380, height: 500)
            .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
            .clipShape(RoundedRectangle(cornerRadius: 12))
            .overlay {
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(.white.opacity(0.16), lineWidth: 1)
            }
    }
}
