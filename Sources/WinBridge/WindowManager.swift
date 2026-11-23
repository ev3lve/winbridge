import Cocoa
import ApplicationServices

enum SnapDirection {
    case left
    case right
    case maximize
    case restore
}

@MainActor
final class WindowManager {
    static let shared = WindowManager()

    func snapActiveWindow(to direction: SnapDirection) {
        guard let frontApp = NSWorkspace.shared.frontmostApplication else { return }
        let appElement = AXUIElementCreateApplication(frontApp.processIdentifier)
        var focusedWindow: AnyObject?

        guard AXUIElementCopyAttributeValue(appElement, kAXFocusedWindowAttribute as CFString, &focusedWindow) == .success,
              let window = focusedWindow else {
            return
        }

        let windowElement = window as! AXUIElement

        // Получаем текущие размеры и позицию окна
        var currentPosValue: AnyObject?
        var currentSizeValue: AnyObject?
        AXUIElementCopyAttributeValue(windowElement, kAXPositionAttribute as CFString, &currentPosValue)
        AXUIElementCopyAttributeValue(windowElement, kAXSizeAttribute as CFString, &currentSizeValue)

        var currentPoint = CGPoint.zero
        var currentSize = CGSize.zero
        if let pv = currentPosValue { AXValueGetValue(pv as! AXValue, .cgPoint, &currentPoint) }
        if let sv = currentSizeValue { AXValueGetValue(sv as! AXValue, .cgSize, &currentSize) }

        // Ищем экран, на котором находится окно
        let currentCenter = CGPoint(x: currentPoint.x + currentSize.width / 2, y: currentPoint.y + currentSize.height / 2)
        let targetScreen = NSScreen.screens.first { screen in
            let flippedFrame = NSRect(x: screen.frame.minX, y: NSScreen.screens[0].frame.height - screen.frame.maxY, width: screen.frame.width, height: screen.frame.height)
            return flippedFrame.contains(currentCenter)
        } ?? NSScreen.main ?? NSScreen.screens[0]

        let visibleFrame = targetScreen.visibleFrame // область без Dock и Menu Bar
        let primaryHeight = NSScreen.screens[0].frame.height

        // Преобразование координат Cocoa (снизу-вверх) в координаты экранных окон (сверху-вниз)
        let topY = primaryHeight - visibleFrame.maxY
        let screenWidth = visibleFrame.width
        let screenHeight = visibleFrame.height
        let startX = visibleFrame.minX

        var targetRect: CGRect

        switch direction {
        case .left:
            targetRect = CGRect(x: startX, y: topY, width: screenWidth / 2, height: screenHeight)
        case .right:
            targetRect = CGRect(x: startX + screenWidth / 2, y: topY, width: screenWidth / 2, height: screenHeight)
        case .maximize:
            targetRect = CGRect(x: startX, y: topY, width: screenWidth, height: screenHeight)
        case .restore:
            let w = screenWidth * 0.7
            let h = screenHeight * 0.7
            targetRect = CGRect(x: startX + (screenWidth - w) / 2, y: topY + (screenHeight - h) / 2, width: w, height: h)
        }

        var newPos = targetRect.origin
        var newSize = targetRect.size

        if let posVal = AXValueCreate(.cgPoint, &newPos),
           let sizeVal = AXValueCreate(.cgSize, &newSize) {
            // Устанавливаем позицию и размер
            AXUIElementSetAttributeValue(windowElement, kAXPositionAttribute as CFString, posVal)
            AXUIElementSetAttributeValue(windowElement, kAXSizeAttribute as CFString, sizeVal)
            // Повторно позицию для надежности (некоторые окна сопротивляются первому изменению)
            AXUIElementSetAttributeValue(windowElement, kAXPositionAttribute as CFString, posVal)
            logDebug("🪟 [WinBridge] Snap активного окна (\(frontApp.localizedName ?? "")) -> \(direction)")
        }
    }

    func lockScreen() {
        logDebug("🔒 [WinBridge] Блокировка экрана (Win + L)")
        typealias SACLockScreenImmediateFunc = @convention(c) () -> Void
        if let handle = dlopen("/System/Library/PrivateFrameworks/login.framework/Versions/Current/login", RTLD_LAZY) {
            if let sym = dlsym(handle, "SACLockScreenImmediate") {
                let lockFunc = unsafeBitCast(sym, to: SACLockScreenImmediateFunc.self)
                lockFunc()
                dlclose(handle)
                return
            }
            dlclose(handle)
        }

        // Запасной вариант через AppleScript (Cmd+Ctrl+Q)
        let script = "tell application \"System Events\" to key code 12 using {command down, control down}"
        if let appleScript = NSAppleScript(source: script) {
            var error: NSDictionary?
            appleScript.executeAndReturnError(&error)
        }
    }

    func showDesktop() {
        logDebug("🖥 [WinBridge] Показать рабочий стол (Win + D)")
        guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
        // F11 (код 103) в macOS — стандартный шорткат Показать рабочий стол
        if let down = CGEvent(keyboardEventSource: source, virtualKey: 103, keyDown: true),
           let up = CGEvent(keyboardEventSource: source, virtualKey: 103, keyDown: false) {
            down.post(tap: CGEventTapLocation.cghidEventTap)
            up.post(tap: CGEventTapLocation.cghidEventTap)
        }
    }

    func openActivityMonitor() {
        logDebug("⚡️ [WinBridge] Открытие Диспетчера задач (Ctrl + Shift + Esc)")
        let url = URL(fileURLWithPath: "/System/Applications/Utilities/Activity Monitor.app")
        NSWorkspace.shared.open(url)
    }

    func openFinder() {
        logDebug("📂 [WinBridge] Открытие Проводника (Win + E)")
        let home = FileManager.default.homeDirectoryForCurrentUser
        NSWorkspace.shared.open(home)
    }
}
