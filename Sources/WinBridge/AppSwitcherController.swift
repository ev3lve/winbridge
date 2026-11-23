import Cocoa
import SwiftUI
import ApplicationServices

struct SwitcherItem: Identifiable, Equatable {
    let id: pid_t
    let name: String
    let icon: NSImage
    let windowTitle: String
    let runningApp: NSRunningApplication

    static func == (lhs: SwitcherItem, rhs: SwitcherItem) -> Bool {
        return lhs.id == rhs.id
    }
}

@MainActor
final class AppSwitcherController: ObservableObject {
    static let shared = AppSwitcherController()

    @Published var items: [SwitcherItem] = []
    @Published var selectedIndex: Int = 0

    private var panel: NSPanel?
    private(set) var isVisible: Bool = false

    private init() {}

    private func setupPanel() {
        if panel != nil { return }

        let p = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: 720, height: 230),
            styleMask: [.nonactivatingPanel, .borderless],
            backing: .buffered,
            defer: false
        )
        p.level = .floating
        p.isOpaque = false
        p.backgroundColor = .clear
        p.hasShadow = true
        p.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let hostingView = NSHostingView(rootView: AppSwitcherView())
        p.contentView = hostingView
        self.panel = p
    }

    func cycle(reverse: Bool = false) {
        if !isVisible {
            // Открываем переключатель
            refreshItems()
            guard !items.isEmpty else { return }

            setupPanel()

            // Если приложений >= 2, по умолчанию выбираем второе (предыдущее активное, как в Windows)
            if items.count > 1 {
                selectedIndex = reverse ? (items.count - 1) : 1
            } else {
                selectedIndex = 0
            }

            positionPanel()
            panel?.makeKeyAndOrderFront(nil)
            isVisible = true
            logDebug("🪟 [WinBridge] Alt+Tab открыт: выбрано [\(selectedIndex)] \(items[selectedIndex].name)")
        } else {
            // Переключаем на следующее/предыдущее
            guard !items.isEmpty else { return }
            if reverse {
                selectedIndex = (selectedIndex - 1 + items.count) % items.count
            } else {
                selectedIndex = (selectedIndex + 1) % items.count
            }
            logDebug("🪟 [WinBridge] Alt+Tab шаг -> [\(selectedIndex)] \(items[selectedIndex].name)")
        }
    }

    func commit() {
        guard isVisible else { return }
        isVisible = false
        EventTapManager.shared.isSwitcherVisible = false
        panel?.orderOut(nil)

        guard selectedIndex >= 0 && selectedIndex < items.count else { return }
        let target = items[selectedIndex]
        logDebug("🚀 [WinBridge] Alt+Tab переключение на: \(target.name) (PID: \(target.id))")

        let app = target.runningApp
        app.activate(options: [.activateIgnoringOtherApps, .activateAllWindows])

        // Дополнительно поднимаем главное окно через AXUIElement
        let appElem = AXUIElementCreateApplication(app.processIdentifier)
        var focusedWindow: AnyObject?
        if AXUIElementCopyAttributeValue(appElem, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
           let win = focusedWindow {
            AXUIElementPerformAction(win as! AXUIElement, kAXRaiseAction as CFString)
        }
    }

    func cancel() {
        guard isVisible else { return }
        isVisible = false
        EventTapManager.shared.isSwitcherVisible = false
        panel?.orderOut(nil)
        logDebug("🚫 [WinBridge] Alt+Tab отменен")
    }

    func selectAndCommit(index: Int) {
        guard index >= 0 && index < items.count else { return }
        selectedIndex = index
        commit()
    }

    private func positionPanel() {
        guard let p = panel else { return }
        let screen = NSScreen.main ?? NSScreen.screens.first!
        let screenFrame = screen.visibleFrame

        // Динамический расчет ширины на основе количества элементов
        let itemWidth: CGFloat = 120
        let padding: CGFloat = 40
        let totalWidth = min(max(CGFloat(items.count) * itemWidth + padding, 480), screenFrame.width * 0.85)
        let height: CGFloat = 210

        let x = screenFrame.origin.x + (screenFrame.width - totalWidth) / 2
        let y = screenFrame.origin.y + (screenFrame.height - height) / 2

        p.setFrame(NSRect(x: x, y: y, width: totalWidth, height: height), display: true)
    }

    private func refreshItems() {
        let currentAppPid = NSRunningApplication.current.processIdentifier
        let windows = CGWindowListCopyWindowInfo([.optionOnScreenOnly, .excludeDesktopElements], kCGNullWindowID) as? [[String: Any]] ?? []

        var seenPids = Set<pid_t>()
        var result: [SwitcherItem] = []

        // 1. Окна на экране в актуальном Z-порядке (MRU)
        for w in windows {
            guard let layer = w[kCGWindowLayer as String] as? Int, layer == 0,
                  let pid = w[kCGWindowOwnerPID as String] as? pid_t,
                  pid != currentAppPid,
                  !seenPids.contains(pid),
                  let app = NSRunningApplication(processIdentifier: pid),
                  app.activationPolicy == .regular,
                  let bounds = w[kCGWindowBounds as String] as? [String: Any],
                  let h = bounds["Height"] as? CGFloat, h > 50,
                  let width = bounds["Width"] as? CGFloat, width > 50 else { continue }

            seenPids.insert(pid)
            let name = app.localizedName ?? "Приложение"
            let icon = app.icon ?? NSWorkspace.shared.icon(for: .application)
            let title = w[kCGWindowName as String] as? String ?? ""
            result.append(SwitcherItem(id: pid, name: name, icon: icon, windowTitle: title, runningApp: app))
        }

        // 2. Добавляем остальные запущенные приложения (свернутые или на других Spaces)
        for app in NSWorkspace.shared.runningApplications {
            if app.activationPolicy == .regular && !seenPids.contains(app.processIdentifier) && app.processIdentifier != currentAppPid && !app.isTerminated {
                seenPids.insert(app.processIdentifier)
                let name = app.localizedName ?? "Приложение"
                let icon = app.icon ?? NSWorkspace.shared.icon(for: .application)
                result.append(SwitcherItem(id: app.processIdentifier, name: name, icon: icon, windowTitle: "", runningApp: app))
            }
        }

        self.items = result
    }
}
