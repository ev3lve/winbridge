import Cocoa
import ApplicationServices
import CoreGraphics

func logDebug(_ message: String) {
    let line = "[\(Date())] \(message)\n"
    if let data = line.data(using: .utf8) {
        if let fileHandle = FileHandle(forWritingAtPath: "/tmp/wintomac.log") {
            fileHandle.seekToEndOfFile()
            fileHandle.write(data)
            try? fileHandle.close()
        } else {
            FileManager.default.createFile(atPath: "/tmp/wintomac.log", contents: data, attributes: nil)
        }
    }
}

final class EventTapManager: @unchecked Sendable {
    static let shared = EventTapManager()
    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?
    private var isLangSwitchCandidate = false

    var isTapActive: Bool {
        return eventTap != nil
    }

    private func isEnabled(_ key: String, defaultVal: Bool = true) -> Bool {
        if UserDefaults.standard.object(forKey: key) == nil {
            return defaultVal
        }
        return UserDefaults.standard.bool(forKey: key)
    }

    func start() {
        if eventTap != nil { return }

        let promptKey = "AXTrustedCheckOptionPrompt" as CFString
        let options = [promptKey: kCFBooleanTrue] as CFDictionary
        let trusted = AXIsProcessTrustedWithOptions(options)

        logDebug("EventTapManager.start() called. AXIsProcessTrusted = \(trusted)")

        guard trusted else {
            logDebug("⚠️ [WinToMac] Права Accessibility не выданы. Ожидание пользователя...")
            return
        }

        // Перехватываем keyDown, keyUp, flagsChanged (раскладка) и scrollWheel (скролл мыши)
        let eventMask = (1 << CGEventType.keyDown.rawValue) |
                        (1 << CGEventType.keyUp.rawValue) |
                        (1 << CGEventType.flagsChanged.rawValue) |
                        (1 << CGEventType.scrollWheel.rawValue)

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: CGEventMask(eventMask),
            callback: { (proxy, type, event, refcon) -> Unmanaged<CGEvent>? in
                return EventTapManager.shared.handleEvent(proxy: proxy, type: type, event: event)
            },
            userInfo: nil
        ) else {
            logDebug("❌ [WinToMac] CGEvent.tapCreate вернул nil!")
            return
        }

        self.eventTap = tap
        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        self.runLoopSource = source
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)
        logDebug("✅ [WinToMac] CGEventTap перехватчик успешно создан и запущен!")
    }

    func handleEvent(proxy: CGEventTapProxy, type: CGEventType, event: CGEvent) -> Unmanaged<CGEvent>? {
        if type == .tapDisabledByTimeout || type == .tapDisabledByUserInput {
            if let tap = eventTap {
                CGEvent.tapEnable(tap: tap, enable: true)
                logDebug("🔄 [WinToMac] EventTap восстановлен после timeout")
            }
            return Unmanaged.passRetained(event)
        }

        // 1. Раздельный виндовый скролл для мыши (инверсия колесика мыши без затрагивания тачпада)
        if type == .scrollWheel && isEnabled("isWindowsMouseScrollEnabled") {
            let isContinuous = event.getIntegerValueField(.scrollWheelEventIsContinuous)
            // isContinuous == 0 означает физическое дискретное колесо мыши, а не тачпад!
            if isContinuous == 0 {
                let deltaPointY = event.getIntegerValueField(.scrollWheelEventPointDeltaAxis1)
                let deltaFixedY = event.getIntegerValueField(.scrollWheelEventDeltaAxis1)
                event.setIntegerValueField(.scrollWheelEventPointDeltaAxis1, value: -deltaPointY)
                event.setIntegerValueField(.scrollWheelEventDeltaAxis1, value: -deltaFixedY)
                return Unmanaged.passRetained(event)
            }
            return Unmanaged.passRetained(event)
        }

        let flags = event.flags
        let hasCmd = flags.contains(.maskCommand)
        let hasCtrl = flags.contains(.maskControl)
        let hasShift = flags.contains(.maskShift)
        let hasAlt = flags.contains(.maskAlternate)

        // 2. Переключение языка ввода по Alt + Shift или Ctrl + Shift (как в Windows)
        if type == .flagsChanged {
            let pureModifiers = flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift])
            let isAltShift = (pureModifiers == [.maskAlternate, .maskShift])
            let isCtrlShift = (pureModifiers == [.maskCommand, .maskShift]) || (pureModifiers == [.maskControl, .maskShift])

            if isAltShift || isCtrlShift {
                isLangSwitchCandidate = true
            } else if isLangSwitchCandidate {
                isLangSwitchCandidate = false
                if isEnabled("isAltShiftSwitchEnabled") {
                    logDebug("🌐 [WinToMac] Сработал Alt+Shift / Ctrl+Shift -> смена раскладки")
                    DispatchQueue.main.async {
                        InputSourceManager.shared.cycleInputSource()
                    }
                }
            }
            return Unmanaged.passRetained(event)
        }

        if type == .keyDown {
            isLangSwitchCandidate = false
        }

        if type != .keyDown && type != .keyUp {
            return Unmanaged.passRetained(event)
        }

        let keyCode = CGKeyCode(event.getIntegerValueField(.keyboardEventKeycode))

        // 3. Виндовый Ctrl + Backspace (код 51) -> стирает ровно одно слово назад ВЕЗДЕ
        if isEnabled("isCtrlBackspaceEnabled") && keyCode == 51 && (hasCmd || hasCtrl) && !hasShift && !hasAlt {
            var newFlags = flags
            newFlags.remove([.maskCommand, .maskControl])
            newFlags.insert(.maskAlternate)
            event.flags = newFlags
            if type == .keyDown {
                logDebug("🎯 [WinToMac] Сработал Ctrl+Backspace -> подменен на Option+Backspace")
            }
            return Unmanaged.passRetained(event)
        }

        // 4. Виндовый Ctrl + Delete (код 117 - Forward Delete) -> стирает слово вперед
        if isEnabled("isCtrlBackspaceEnabled") && keyCode == 117 && (hasCmd || hasCtrl) && !hasShift && !hasAlt {
            var newFlags = flags
            newFlags.remove([.maskCommand, .maskControl])
            newFlags.insert(.maskAlternate)
            event.flags = newFlags
            if type == .keyDown {
                logDebug("🎯 [WinToMac] Сработал Ctrl+Delete -> подменен на Option+Delete")
            }
            return Unmanaged.passRetained(event)
        }

        // 5. Прыжки и выделение по словам: Ctrl + Left Arrow (123) / Right Arrow (124)
        if isEnabled("isWordJumpEnabled") && (keyCode == 123 || keyCode == 124) && (hasCmd || hasCtrl) && !hasAlt {
            var newFlags = flags
            newFlags.remove([.maskCommand, .maskControl])
            newFlags.insert(.maskAlternate)
            event.flags = newFlags
            if type == .keyDown {
                logDebug("🎯 [WinToMac] Сработал Ctrl+Стрелка (\(keyCode)) -> подменен на Option+Стрелка (Shift=\(hasShift))")
            }
            return Unmanaged.passRetained(event)
        }

        // Все последующие действия обрабатываются только при keyDown
        if type != .keyDown {
            return Unmanaged.passRetained(event)
        }

        // 6. Буфер обмена как в Windows: Win + V (код 9 = 'V')
        if isEnabled("isClipboardHistoryEnabled") && keyCode == 9 && hasCtrl && !hasCmd && !hasAlt && !hasShift {
            logDebug("📋 [WinToMac] Нажато Win + V -> открытие истории буфера обмена")
            DispatchQueue.main.async {
                ClipboardWindowController.shared.toggle()
            }
            return nil
        }

        // 7. Виндовый Snap окон (Win + Стрелки: 123=Left, 124=Right, 126=Up/Maximize, 125=Down/Restore)
        if isEnabled("isWindowSnapEnabled") && hasCtrl && !hasCmd && !hasAlt && !hasShift {
            if keyCode == 123 { // Win + Left
                DispatchQueue.main.async { WindowManager.shared.snapActiveWindow(to: .left) }
                return nil
            } else if keyCode == 124 { // Win + Right
                DispatchQueue.main.async { WindowManager.shared.snapActiveWindow(to: .right) }
                return nil
            } else if keyCode == 126 { // Win + Up (Maximize)
                DispatchQueue.main.async { WindowManager.shared.snapActiveWindow(to: .maximize) }
                return nil
            } else if keyCode == 125 { // Win + Down (Restore/Center)
                DispatchQueue.main.async { WindowManager.shared.snapActiveWindow(to: .restore) }
                return nil
            }
        }

        // 8. Глобальные шорткаты Windows
        if isEnabled("isGlobalShortcutsEnabled") {
            // Win + E (код 14 = 'E') -> Открыть Проводник
            if keyCode == 14 && hasCtrl && !hasCmd && !hasAlt && !hasShift {
                DispatchQueue.main.async { WindowManager.shared.openFinder() }
                return nil
            }

            // Win + D (код 2 = 'D') -> Свернуть все окна / Рабочий стол
            if keyCode == 2 && hasCtrl && !hasCmd && !hasAlt && !hasShift {
                DispatchQueue.main.async { WindowManager.shared.showDesktop() }
                return nil
            }

            // Win + L (код 37 = 'L') -> Заблокировать экран
            if keyCode == 37 && hasCtrl && !hasCmd && !hasAlt && !hasShift {
                DispatchQueue.main.async { WindowManager.shared.lockScreen() }
                return nil
            }

            // Ctrl + Shift + Esc (код 53 = Esc) -> Диспетчер задач
            if keyCode == 53 && (hasCmd || hasCtrl) && hasShift && !hasAlt {
                DispatchQueue.main.async { WindowManager.shared.openActivityMonitor() }
                return nil
            }
        }

        // 8.1. Закрытие программ по Alt + F4 (код 118 = F4)
        if isEnabled("isAltF4Enabled") && keyCode == 118 && hasAlt && !hasCmd && !hasCtrl && !hasShift {
            logDebug("🚪 [WinToMac] Нажато Alt + F4 -> закрытие активного приложения")
            guard let source = CGEventSource(stateID: .combinedSessionState) else { return nil }
            let isFinder = NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.finder"
            let targetKey: CGKeyCode = isFinder ? 13 : 12 // 13 = 'W' (закрыть окно), 12 = 'Q' (выйти)
            if let down = CGEvent(keyboardEventSource: source, virtualKey: targetKey, keyDown: true),
               let up = CGEvent(keyboardEventSource: source, virtualKey: targetKey, keyDown: false) {
                down.flags = .maskCommand
                up.flags = .maskCommand
                down.post(tap: CGEventTapLocation.cgAnnotatedSessionEventTap)
                up.post(tap: CGEventTapLocation.cgAnnotatedSessionEventTap)
            }
            return nil
        }

        // 9. Скриншот области (Ножницы): Win + Shift + S / Ctrl + Shift + S (код 1 = 'S', 57 = CapsLock)
        if isEnabled("isScreenshotEnabled") && (keyCode == 1 || keyCode == 57) && (hasCtrl || hasCmd) && hasShift && !hasAlt {
            logDebug("📸 [WinToMac] Сработал скриншот области! Запуск screencapture -i -c")
            DispatchQueue.global(qos: .userInteractive).async {
                let task = Process()
                task.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
                task.arguments = ["-i", "-c"]
                try? task.run()
            }
            return nil
        }

        // 10. Клавиши Home (115) и End (119)
        if isEnabled("isHomeEndEnabled") && (keyCode == 115 || keyCode == 119) {
            guard let source = CGEventSource(stateID: .combinedSessionState) else {
                return Unmanaged.passRetained(event)
            }
            let targetKey: CGKeyCode
            var targetFlags: CGEventFlags = .maskCommand

            if keyCode == 115 {
                targetKey = (hasCtrl || hasCmd) ? 126 : 123
            } else {
                targetKey = (hasCtrl || hasCmd) ? 125 : 124
            }

            if hasShift { targetFlags.insert(.maskShift) }

            if let down = CGEvent(keyboardEventSource: source, virtualKey: targetKey, keyDown: true),
               let up = CGEvent(keyboardEventSource: source, virtualKey: targetKey, keyDown: false) {
                down.flags = targetFlags
                up.flags = targetFlags
                down.post(tap: CGEventTapLocation.cgAnnotatedSessionEventTap)
                up.post(tap: CGEventTapLocation.cgAnnotatedSessionEventTap)
                return nil
            }
        }

        // 11. Улучшения Проводника (Finder)
        if let frontmost = NSWorkspace.shared.frontmostApplication, frontmost.bundleIdentifier == "com.apple.finder" {
            let pureModifiers = flags.intersection([.maskCommand, .maskControl, .maskAlternate, .maskShift])

            // Базовые фичи: Enter = Открыть, F2 = Переименовать
            if isEnabled("isFinderFixEnabled") && pureModifiers.isEmpty {
                guard let source = CGEventSource(stateID: .combinedSessionState) else { return Unmanaged.passRetained(event) }
                if keyCode == 36 { // Enter -> Cmd + Down Arrow
                    if let down = CGEvent(keyboardEventSource: source, virtualKey: 125, keyDown: true),
                       let up = CGEvent(keyboardEventSource: source, virtualKey: 125, keyDown: false) {
                        down.flags = .maskCommand
                        up.flags = .maskCommand
                        down.post(tap: CGEventTapLocation.cgAnnotatedSessionEventTap)
                        up.post(tap: CGEventTapLocation.cgAnnotatedSessionEventTap)
                        logDebug("🎯 [WinToMac] Finder: Enter -> Открыть файл")
                        return nil
                    }
                } else if keyCode == 120 { // F2 -> Return
                    if let down = CGEvent(keyboardEventSource: source, virtualKey: 36, keyDown: true),
                       let up = CGEvent(keyboardEventSource: source, virtualKey: 36, keyDown: false) {
                        down.post(tap: CGEventTapLocation.cgAnnotatedSessionEventTap)
                        up.post(tap: CGEventTapLocation.cgAnnotatedSessionEventTap)
                        logDebug("🎯 [WinToMac] Finder: F2 -> Переименовать")
                        return nil
                    }
                }
            }

            // Дополнительные фичи: Delete удаляет в корзину, Backspace идет вверх, Ctrl+H скрытые файлы
            if isEnabled("isFinderExtrasEnabled") {
                guard let source = CGEventSource(stateID: .combinedSessionState) else { return Unmanaged.passRetained(event) }

                // Клавиша Delete (код 117 - Del) -> переместить в корзину (Cmd + Backspace)
                if keyCode == 117 && pureModifiers.isEmpty {
                    if let down = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: true),
                       let up = CGEvent(keyboardEventSource: source, virtualKey: 51, keyDown: false) {
                        down.flags = .maskCommand
                        up.flags = .maskCommand
                        down.post(tap: CGEventTapLocation.cgAnnotatedSessionEventTap)
                        up.post(tap: CGEventTapLocation.cgAnnotatedSessionEventTap)
                        logDebug("📂 [WinToMac] Finder: Del -> Переместить в корзину (Cmd+Del)")
                        return nil
                    }
                }

                // Клавиша Backspace (код 51) без модификаторов -> на папку вверх (Cmd + Up Arrow)
                if keyCode == 51 && pureModifiers.isEmpty {
                    if let down = CGEvent(keyboardEventSource: source, virtualKey: 126, keyDown: true),
                       let up = CGEvent(keyboardEventSource: source, virtualKey: 126, keyDown: false) {
                        down.flags = .maskCommand
                        up.flags = .maskCommand
                        down.post(tap: CGEventTapLocation.cgAnnotatedSessionEventTap)
                        up.post(tap: CGEventTapLocation.cgAnnotatedSessionEventTap)
                        logDebug("📂 [WinToMac] Finder: Backspace -> На папку выше (Cmd+Up)")
                        return nil
                    }
                }

                // Ctrl + H (код 4 = 'H') -> Показать/скрыть скрытые файлы (Cmd + Shift + .)
                if keyCode == 4 && (hasCmd || hasCtrl) && !hasAlt && !hasShift {
                    // Код клавиши 47 = '.'
                    if let down = CGEvent(keyboardEventSource: source, virtualKey: 47, keyDown: true),
                       let up = CGEvent(keyboardEventSource: source, virtualKey: 47, keyDown: false) {
                        down.flags = [.maskCommand, .maskShift]
                        up.flags = [.maskCommand, .maskShift]
                        down.post(tap: CGEventTapLocation.cgAnnotatedSessionEventTap)
                        up.post(tap: CGEventTapLocation.cgAnnotatedSessionEventTap)
                        logDebug("📂 [WinToMac] Finder: Ctrl + H -> Переключение скрытых файлов")
                        return nil
                    }
                }
            }
        }

        return Unmanaged.passRetained(event)
    }
}
