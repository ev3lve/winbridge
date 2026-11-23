import Cocoa
import SwiftUI

@MainActor
final class StatusBarController: NSObject {
    private var statusItem: NSStatusItem!
    private var popover: NSPopover!

    override init() {
        super.init()
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)

        if let button = statusItem.button {
            button.image = NSImage(systemSymbolName: "keyboard", accessibilityDescription: "WinBridge")
            button.action = #selector(togglePopover)
            button.target = self
        }

        popover = NSPopover()
        popover.contentSize = NSSize(width: 320, height: 530)
        popover.behavior = .transient
        popover.contentViewController = NSHostingController(rootView: MainSettingsView())
    }

    @objc func togglePopover() {
        if let button = statusItem.button {
            if popover.isShown {
                popover.performClose(nil)
            } else {
                popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
                popover.contentViewController?.view.window?.makeKey()
            }
        }
    }

    func closePopover() {
        popover.performClose(nil)
    }
}

@main
@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusBar: StatusBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Устанавливаем политику отображения (Dock + Menu Bar)
        let showInDock = AppSettings.shared.isShowInDockEnabled
        AppSettings.shared.updateActivationPolicy(showInDock)

        statusBar = StatusBarController()
        EventTapManager.shared.start()

        // Показываем главное окно приложения при первом запуске
        MainWindowController.shared.show()
        print("🚀 [WinBridge] Запущен: главное окно + Menu Bar (трей)!")
    }

    // При клике на иконку в Dock открываем главное окно
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows flag: Bool) -> Bool {
        MainWindowController.shared.show()
        return true
    }

    static func main() {
        let app = NSApplication.shared
        let delegate = AppDelegate()
        app.delegate = delegate
        app.run()
    }
}
