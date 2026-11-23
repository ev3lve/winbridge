import Cocoa
import SwiftUI

@MainActor
final class ClipboardPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }

    override func cancelOperation(_ sender: Any?) {
        ClipboardWindowController.shared.hide()
    }
}

@MainActor
final class ClipboardWindowController: NSObject, ObservableObject {
    static let shared = ClipboardWindowController()
    private var window: ClipboardPanel?
    private var resignObserver: Any?

    func toggle() {
        if let win = window, win.isVisible {
            hide()
        } else {
            show()
        }
    }

    func show() {
        if window == nil {
            let panel = ClipboardPanel(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 480),
                styleMask: [.titled, .closable, .fullSizeContentView, .nonactivatingPanel],
                backing: .buffered,
                defer: false
            )
            panel.isFloatingPanel = true
            panel.level = .floating
            panel.titleVisibility = .hidden
            panel.titlebarAppearsTransparent = true
            panel.isMovableByWindowBackground = true
            panel.hidesOnDeactivate = false
            panel.hasShadow = true
            panel.isOpaque = false
            panel.backgroundColor = .clear

            let hostingView = NSHostingView(rootView: ClipboardHistoryView())
            panel.contentView = hostingView
            self.window = panel

            // Закрывать окно при клике в любое другое место
            self.resignObserver = NotificationCenter.default.addObserver(
                forName: NSWindow.didResignKeyNotification,
                object: panel,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.hide()
                }
            }
        }

        guard let win = window else { return }
        win.center()
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }

    func hide() {
        window?.orderOut(nil)
    }
}
