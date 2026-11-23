import SwiftUI
import Combine
import ServiceManagement

@MainActor
final class AppSettings: ObservableObject {
    static let shared = AppSettings()

    // Клавиатура и текст
    @AppStorage("isCtrlBackspaceEnabled") var isCtrlBackspaceEnabled: Bool = true
    @AppStorage("isWordJumpEnabled") var isWordJumpEnabled: Bool = true
    @AppStorage("isHomeEndEnabled") var isHomeEndEnabled: Bool = true
    @AppStorage("isScreenshotEnabled") var isScreenshotEnabled: Bool = true
    @AppStorage("isAltShiftSwitchEnabled") var isAltShiftSwitchEnabled: Bool = true

    // Буфер обмена
    @AppStorage("isClipboardHistoryEnabled") var isClipboardHistoryEnabled: Bool = true

    // Глобальные шорткаты Windows (Win+E, Win+D, Win+L, Ctrl+Shift+Esc, Alt+F4)
    @AppStorage("isGlobalShortcutsEnabled") var isGlobalShortcutsEnabled: Bool = true
    @AppStorage("isAltF4Enabled") var isAltF4Enabled: Bool = true

    // Виндовый Snap окон (Win + Стрелки)
    @AppStorage("isWindowSnapEnabled") var isWindowSnapEnabled: Bool = true

    // Проводник (Finder)
    @AppStorage("isFinderFixEnabled") var isFinderFixEnabled: Bool = true
    @AppStorage("isFinderExtrasEnabled") var isFinderExtrasEnabled: Bool = true

    // Мышь и скролл
    @AppStorage("isWindowsMouseScrollEnabled") var isWindowsMouseScrollEnabled: Bool = true
    @AppStorage("isLinearMouseEnabled") var isLinearMouseEnabled: Bool = false {
        didSet {
            applyMouseSettings(isLinearMouseEnabled)
        }
    }

    // Внешний вид и система
    @AppStorage("isShowInDockEnabled") var isShowInDockEnabled: Bool = true {
        didSet {
            updateActivationPolicy(isShowInDockEnabled)
        }
    }
    @AppStorage("isAutoHideFromDockOnClose") var isAutoHideFromDockOnClose: Bool = true

    @Published var isLaunchAtLoginEnabled: Bool = false
    @Published var isAccessibilityGranted: Bool = false
    private var timer: AnyCancellable?

    init() {
        checkAccessibility()
        checkLaunchAtLogin()
        ensureAltTabRunning()
        timer = Timer.publish(every: 1.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.checkAccessibility()
            }
    }

    func ensureAltTabRunning() {
        if FileManager.default.fileExists(atPath: "/Applications/AltTab.app") {
            let running = NSRunningApplication.runningApplications(withBundleIdentifier: "com.lwouis.alt-tab-macos")
            if running.isEmpty {
                NSWorkspace.shared.open(URL(fileURLWithPath: "/Applications/AltTab.app"))
                logDebug("🪟 [WinToMac] Запущен сервис оконного переключения AltTab")
            }
        }
    }

    func checkAccessibility() {
        let trusted = AXIsProcessTrusted()
        if trusted != isAccessibilityGranted {
            self.isAccessibilityGranted = trusted
            logDebug("AppSettings: isAccessibilityGranted changed to: \(trusted)")
        }
        if trusted && !EventTapManager.shared.isTapActive {
            EventTapManager.shared.start()
        }
    }

    func requestAccessibility() {
        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: kCFBooleanTrue] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }

    func openAccessibilitySettings() {
        if let url = URL(string: "x-apple.systempreferences:com.apple.preference.security?Privacy_Accessibility") {
            NSWorkspace.shared.open(url)
        }
    }

    func checkLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            self.isLaunchAtLoginEnabled = (SMAppService.mainApp.status == .enabled)
        }
    }

    func toggleLaunchAtLogin() {
        if #available(macOS 13.0, *) {
            do {
                if SMAppService.mainApp.status == .enabled {
                    try SMAppService.mainApp.unregister()
                    self.isLaunchAtLoginEnabled = false
                    logDebug("⚙️ [WinToMac] Автозапуск отключен")
                } else {
                    try SMAppService.mainApp.register()
                    self.isLaunchAtLoginEnabled = true
                    logDebug("⚙️ [WinToMac] Автозапуск включен через SMAppService")
                }
            } catch {
                print("Failed to toggle launch at login: \(error)")
            }
        }
    }

    func updateActivationPolicy(_ showInDock: Bool) {
        if showInDock {
            NSApp.setActivationPolicy(.regular)
        } else {
            NSApp.setActivationPolicy(.accessory)
        }
        logDebug("⚙️ [WinToMac] ActivationPolicy обновлена: showInDock=\(showInDock)")
    }

    func resetToDefaults() {
        isCtrlBackspaceEnabled = true
        isWordJumpEnabled = true
        isHomeEndEnabled = true
        isScreenshotEnabled = true
        isAltShiftSwitchEnabled = true
        isClipboardHistoryEnabled = true
        isGlobalShortcutsEnabled = true
        isWindowSnapEnabled = true
        isFinderFixEnabled = true
        isFinderExtrasEnabled = true
        isWindowsMouseScrollEnabled = true
        isLinearMouseEnabled = false
        isShowInDockEnabled = true
        logDebug("⚙️ [WinToMac] Все настройки сброшены по умолчанию")
    }

    private func applyMouseSettings(_ linear: Bool) {
        let task = Process()
        task.executableURL = URL(fileURLWithPath: "/usr/bin/defaults")
        task.arguments = ["write", "-g", "com.apple.mouse.scaling", linear ? "-1" : "1.5"]
        try? task.run()
    }
}
