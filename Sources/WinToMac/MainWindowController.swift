import Cocoa
import SwiftUI

@MainActor
final class MainWindowController: NSObject, NSWindowDelegate {
    static let shared = MainWindowController()
    private var window: NSWindow?

    func show() {
        if window == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 860, height: 600),
                styleMask: [.titled, .closable, .miniaturizable, .resizable, .fullSizeContentView],
                backing: .buffered,
                defer: false
            )
            win.title = "WinToMac"
            win.subtitle = "Виндовые привычки на Mac"
            win.titlebarAppearsTransparent = false
            win.toolbarStyle = .unified
            win.delegate = self
            win.center()
            win.setFrameAutosaveName("WinToMacMainWindow")

            let hostingView = NSHostingView(rootView: MainWindowView())
            win.contentView = hostingView
            self.window = win
        }

        guard let win = window else { return }
        if AppSettings.shared.isShowInDockEnabled {
            NSApp.setActivationPolicy(.regular)
        }
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        window?.orderOut(nil)
        if AppSettings.shared.isAutoHideFromDockOnClose {
            NSApp.setActivationPolicy(.accessory)
        }
    }

    func toggle() {
        if let win = window, win.isVisible {
            hide()
        } else {
            show()
        }
    }

    // При нажатии на красный крестик скрываем окно и убираем из Dock, если включено
    func windowShouldClose(_ sender: NSWindow) -> Bool {
        sender.orderOut(nil)
        if AppSettings.shared.isAutoHideFromDockOnClose {
            NSApp.setActivationPolicy(.accessory)
            logDebug("🪟 [WinToMac] Окно закрыто -> значок убран из Dock в фоновый трей")
        }
        return false
    }
}
