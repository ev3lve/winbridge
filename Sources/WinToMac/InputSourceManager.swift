import Carbon
import Cocoa

@MainActor
final class InputSourceManager {
    static let shared = InputSourceManager()

    func cycleInputSource() {
        let properties = [kTISPropertyInputSourceCategory: kTISCategoryKeyboardInputSource] as CFDictionary
        guard let list = TISCreateInputSourceList(properties, false)?.takeRetainedValue() as? [TISInputSource] else {
            return
        }

        let selectable = list.filter {
            guard let isSelectable = TISGetInputSourceProperty($0, kTISPropertyInputSourceIsSelectCapable) else { return false }
            return CFBooleanGetValue(Unmanaged<CFBoolean>.fromOpaque(isSelectable).takeUnretainedValue())
        }

        guard selectable.count > 1 else { return }

        let current = TISCopyCurrentKeyboardInputSource().takeRetainedValue()
        let currentIDPtr = TISGetInputSourceProperty(current, kTISPropertyInputSourceID)
        let currentID = currentIDPtr != nil ? Unmanaged<CFString>.fromOpaque(currentIDPtr!).takeUnretainedValue() as String : ""

        let currentIndex = selectable.firstIndex(where: {
            let idPtr = TISGetInputSourceProperty($0, kTISPropertyInputSourceID)
            let id = idPtr != nil ? Unmanaged<CFString>.fromOpaque(idPtr!).takeUnretainedValue() as String : ""
            return id == currentID
        }) ?? 0

        let nextIndex = (currentIndex + 1) % selectable.count
        let nextSource = selectable[nextIndex]

        let nextNamePtr = TISGetInputSourceProperty(nextSource, kTISPropertyLocalizedName)
        let nextName = nextNamePtr != nil ? Unmanaged<CFString>.fromOpaque(nextNamePtr!).takeUnretainedValue() as String : "Unknown"

        let status = TISSelectInputSource(nextSource)
        if status == noErr {
            logDebug("🌐 [WinToMac] Язык ввода успешно изменен на: \"\(nextName)\" (Alt+Shift)")
        } else {
            logDebug("⚠️ [WinToMac] Ошибка TISSelectInputSource: \(status)")
        }
    }
}
