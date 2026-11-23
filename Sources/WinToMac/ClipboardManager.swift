import Cocoa
import SwiftUI
import Combine

enum ClipboardItemType: String, Codable {
    case text
    case image
}

struct ClipboardItem: Identifiable, Equatable, Codable, Hashable {
    let id: UUID
    let type: ClipboardItemType
    let text: String
    let imageFileName: String?
    let date: Date
    var isPinned: Bool

    init(text: String, date: Date = Date(), isPinned: Bool = false, id: UUID = UUID()) {
        self.id = id
        self.type = .text
        self.text = text
        self.imageFileName = nil
        self.date = date
        self.isPinned = isPinned
    }

    init(imageFileName: String, description: String, date: Date = Date(), isPinned: Bool = false, id: UUID = UUID()) {
        self.id = id
        self.type = .image
        self.text = description
        self.imageFileName = imageFileName
        self.date = date
        self.isPinned = isPinned
    }

    var imageURL: URL? {
        guard let name = imageFileName else { return nil }
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        return appSupport.appendingPathComponent("WinToMac/images", isDirectory: true).appendingPathComponent(name)
    }

    var thumbnailImage: NSImage? {
        guard let url = imageURL, let data = try? Data(contentsOf: url) else { return nil }
        return NSImage(data: data)
    }
}

@MainActor
final class ClipboardManager: ObservableObject {
    static let shared = ClipboardManager()

    @Published var items: [ClipboardItem] = []
    private var lastChangeCount: Int = 0
    private var timer: Timer?

    private var storageDir: URL {
        let appSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        let dir = appSupport.appendingPathComponent("WinToMac", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var imagesDir: URL {
        let dir = storageDir.appendingPathComponent("images", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }

    private var storageURL: URL {
        return storageDir.appendingPathComponent("clipboard_history.json")
    }

    init() {
        lastChangeCount = NSPasteboard.general.changeCount
        loadItems()
        startMonitoring()
    }

    func startMonitoring() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.35, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.checkPasteboard()
            }
        }
    }

    func checkPasteboard() {
        let pasteboard = NSPasteboard.general
        let count = pasteboard.changeCount
        guard count != lastChangeCount else { return }
        lastChangeCount = count

        // 1. Проверяем, скопировано ли изображение (или скриншот Win+Shift+S)
        if let imgData = pasteboard.data(forType: .png) ?? pasteboard.data(forType: .tiff) {
            if let image = NSImage(data: imgData) {
                let w = Int(image.size.width)
                let h = Int(image.size.height)
                if w > 0 && h > 0 {
                    let fileName = "\(UUID().uuidString).png"
                    let fileURL = imagesDir.appendingPathComponent(fileName)

                    if let tiff = image.tiffRepresentation,
                       let rep = NSBitmapImageRep(data: tiff),
                       let png = rep.representation(using: .png, properties: [:]) {
                        try? png.write(to: fileURL)
                    } else {
                        try? imgData.write(to: fileURL)
                    }

                    let desc = "Скриншот / Изображение (\(w) × \(h))"
                    var updated = items
                    updated.insert(ClipboardItem(imageFileName: fileName, description: desc), at: 0)

                    let pinnedCount = updated.filter { $0.isPinned }.count
                    if updated.count > (80 + pinnedCount) {
                        let pinned = updated.filter { $0.isPinned }
                        let unpinned = Array(updated.filter { !$0.isPinned }.prefix(80))
                        updated = pinned + unpinned
                    }

                    self.items = updated
                    saveItems()
                    logDebug("📸 [WinToMac] Сохранено изображение в буфер обмена: \(desc)")
                    return
                }
            }
        }

        // 2. Проверяем текст
        guard let str = pasteboard.string(forType: .string) else { return }
        let trimmed = str.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }

        // Не дублируем самый верхний элемент
        if let first = items.first, first.type == .text && first.text == str {
            return
        }

        var existingPinned = false
        if let existing = items.first(where: { $0.type == .text && $0.text == str }) {
            existingPinned = existing.isPinned
        }

        var updated = items.filter { !($0.type == .text && $0.text == str) }
        updated.insert(ClipboardItem(text: str, isPinned: existingPinned), at: 0)

        let pinnedCount = updated.filter { $0.isPinned }.count
        if updated.count > (100 + pinnedCount) {
            let pinned = updated.filter { $0.isPinned }
            let unpinned = Array(updated.filter { !$0.isPinned }.prefix(100))
            updated = pinned + unpinned
        }

        self.items = updated
        saveItems()

        let preview = str.replacingOccurrences(of: "\n", with: " ").prefix(35)
        logDebug("📋 [WinToMac] Буфер обмена (текст): \"\(preview)...\" (Всего: \(updated.count))")
    }

    func paste(item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if item.type == .image, let url = item.imageURL, let data = try? Data(contentsOf: url), let img = NSImage(data: data) {
            pasteboard.setData(data, forType: .png)
            pasteboard.writeObjects([img])
            logDebug("📋 [WinToMac] Подготовлено изображение для вставки")
        } else {
            pasteboard.setString(item.text, forType: .string)
            logDebug("📋 [WinToMac] Подготовлен текст для вставки: \"\(item.text.prefix(25))...\"")
        }

        lastChangeCount = pasteboard.changeCount
        ClipboardWindowController.shared.hide()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.12) {
            guard let source = CGEventSource(stateID: .combinedSessionState) else { return }
            // Код клавиши 9 = 'v'
            if let down = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: true),
               let up = CGEvent(keyboardEventSource: source, virtualKey: 9, keyDown: false) {
                down.flags = .maskCommand
                up.flags = .maskCommand
                down.post(tap: CGEventTapLocation.cgAnnotatedSessionEventTap)
                up.post(tap: CGEventTapLocation.cgAnnotatedSessionEventTap)
            }
        }
    }

    func copyToClipboard(item: ClipboardItem) {
        let pasteboard = NSPasteboard.general
        pasteboard.clearContents()

        if item.type == .image, let url = item.imageURL, let data = try? Data(contentsOf: url), let img = NSImage(data: data) {
            pasteboard.setData(data, forType: .png)
            pasteboard.writeObjects([img])
            logDebug("📋 [WinToMac] Изображение скопировано в буфер")
        } else {
            pasteboard.setString(item.text, forType: .string)
            logDebug("📋 [WinToMac] Текст скопирован в буфер: \"\(item.text.prefix(30))...\"")
        }

        lastChangeCount = pasteboard.changeCount
    }

    func togglePin(item: ClipboardItem) {
        if let idx = items.firstIndex(where: { $0.id == item.id }) {
            items[idx].isPinned.toggle()
            saveItems()
            logDebug("📌 [WinToMac] Статус pin изменен: \(items[idx].isPinned) для \"\(item.text.prefix(25))...\"")
        }
    }

    func delete(item: ClipboardItem) {
        if item.type == .image, let url = item.imageURL {
            try? FileManager.default.removeItem(at: url)
        }
        items.removeAll { $0.id == item.id }
        saveItems()
    }

    func clearAll() {
        let unpinned = items.filter { !$0.isPinned }
        for it in unpinned {
            if it.type == .image, let url = it.imageURL {
                try? FileManager.default.removeItem(at: url)
            }
        }
        items = items.filter { $0.isPinned }
        saveItems()
        logDebug("📋 [WinToMac] Буфер обмена очищен (закрепленные сохранены)")
    }

    private func saveItems() {
        do {
            let data = try JSONEncoder().encode(items)
            try data.write(to: storageURL, options: .atomic)
        } catch {
            print("Failed to save clipboard items: \(error)")
        }
    }

    private func loadItems() {
        guard FileManager.default.fileExists(atPath: storageURL.path) else { return }
        do {
            let data = try Data(contentsOf: storageURL)
            self.items = try JSONDecoder().decode([ClipboardItem].self, from: data)
            logDebug("📋 [WinToMac] Загружено \(items.count) сохраненных записей буфера обмена")
        } catch {
            print("Failed to load clipboard items: \(error)")
        }
    }
}
