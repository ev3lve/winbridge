import SwiftUI

struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: Context) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.blendingMode = .behindWindow
        view.state = .active
        view.material = .hudWindow
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: Context) {}
}

struct ClipboardHistoryView: View {
    @ObservedObject var manager = ClipboardManager.shared
    @State private var searchText = ""
    @State private var hoveredItemId: UUID?
    @State private var localMonitor: Any?

    var filteredItems: [ClipboardItem] {
        if searchText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return manager.items
        } else {
            return manager.items.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Заголовок
            HStack(spacing: 8) {
                Image(systemName: "doc.on.clipboard.fill")
                    .font(.title3)
                    .foregroundStyle(.blue)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text("Буфер обмена")
                            .font(.headline)
                            .fontWeight(.bold)

                        Text("Win + V")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .padding(.horizontal, 5)
                            .padding(.vertical, 2)
                            .background(Color.blue.opacity(0.18))
                            .foregroundStyle(.blue)
                            .cornerRadius(4)
                    }

                    Text("\(manager.items.count) элементов")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if !manager.items.isEmpty {
                    Button(action: {
                        manager.clearAll()
                    }) {
                        Image(systemName: "trash")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                    .help("Очистить историю")
                    .padding(6)
                }

                Button(action: {
                    ClipboardWindowController.shared.hide()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.body)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .help("Закрыть (Esc)")
                .padding(4)
            }
            .padding(.horizontal, 14)
            .padding(.top, 14)
            .padding(.bottom, 10)

            // Поисковая строка
            HStack {
                Image(systemName: "magnifyingglass")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                TextField("Поиск по тексту...", text: $searchText)
                    .textFieldStyle(.plain)
                    .font(.subheadline)

                if !searchText.isEmpty {
                    Button(action: { searchText = "" }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(8)
            .background(Color(NSColor.controlBackgroundColor).opacity(0.8))
            .cornerRadius(8)
            .padding(.horizontal, 14)
            .padding(.bottom, 10)

            Divider()

            // Список элементов
            if filteredItems.isEmpty {
                VStack(spacing: 12) {
                    Spacer()
                    Image(systemName: "clipboard")
                        .font(.system(size: 38))
                        .foregroundStyle(.secondary.opacity(0.5))
                    Text(searchText.isEmpty ? "Буфер обмена пуст" : "Ничего не найдено")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text(searchText.isEmpty ? "Скопируйте текст (Ctrl + C), и он появится здесь" : "Попробуйте изменить поисковый запрос")
                        .font(.caption)
                        .foregroundStyle(.secondary.opacity(0.8))
                        .multilineTextAlignment(.center)
                    Spacer()
                }
                .padding()
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 8) {
                        ForEach(Array(filteredItems.enumerated()), id: \.element.id) { index, item in
                            ClipboardItemRow(
                                item: item,
                                index: index + 1,
                                isHovered: hoveredItemId == item.id,
                                onSelect: {
                                    manager.paste(item: item)
                                },
                                onDelete: {
                                    manager.delete(item: item)
                                }
                            )
                            .onHover { hovering in
                                if hovering {
                                    hoveredItemId = item.id
                                } else if hoveredItemId == item.id {
                                    hoveredItemId = nil
                                }
                            }
                        }
                    }
                    .padding(12)
                }
            }

            Divider()

            // Подсказка снизу
            HStack {
                Text("💡 Нажмите на карточку или цифру (1-9) для вставки")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Esc — закрыть")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor).opacity(0.5))
        }
        .frame(width: 380, height: 480)
        .background(VisualEffectBackground())
        .clipShape(RoundedRectangle(cornerRadius: 14))
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.white.opacity(0.15), lineWidth: 1)
        )
        .onAppear {
            setupKeyMonitor()
        }
        .onDisappear {
            removeKeyMonitor()
        }
    }

    private func setupKeyMonitor() {
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            // Esc -> закрыть
            if event.keyCode == 53 {
                ClipboardWindowController.shared.hide()
                return nil
            }

            // Enter -> вставить первый элемент
            if event.keyCode == 36 && !filteredItems.isEmpty {
                manager.paste(item: filteredItems[0])
                return nil
            }

            // Цифры 1..9 для быстрой вставки
            if let chars = event.characters, let num = Int(chars), num >= 1 && num <= 9 {
                let targetIndex = num - 1
                if targetIndex < filteredItems.count {
                    manager.paste(item: filteredItems[targetIndex])
                    return nil
                }
            }

            return event
        }
    }

    private func removeKeyMonitor() {
        if let monitor = localMonitor {
            NSEvent.removeMonitor(monitor)
            localMonitor = nil
        }
    }
}

struct ClipboardItemRow: View {
    let item: ClipboardItem
    let index: Int
    let isHovered: Bool
    let onSelect: () -> Void
    let onDelete: () -> Void

    var timeFormatted: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: item.date)
    }

    var body: some View {
        Button(action: onSelect) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(alignment: .top) {
                    if index <= 9 {
                        Text("\(index)")
                            .font(.system(size: 10, weight: .bold, design: .monospaced))
                            .foregroundStyle(Color.blue)
                            .frame(width: 18, height: 18)
                            .background(Color.blue.opacity(0.12))
                            .cornerRadius(4)
                    }

                    if item.type == .image {
                        Image(systemName: "photo")
                            .font(.caption2)
                            .foregroundStyle(.blue)
                    }

                    Text(item.text)
                        .font(.subheadline)
                        .lineLimit(2)
                        .multilineTextAlignment(.leading)
                        .foregroundStyle(Color.primary)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    if item.isPinned {
                        Image(systemName: "pin.fill")
                            .font(.caption2)
                            .foregroundStyle(.orange)
                    }

                    if isHovered {
                        Button(action: {
                            ClipboardManager.shared.togglePin(item: item)
                        }) {
                            Image(systemName: item.isPinned ? "pin.slash.fill" : "pin")
                                .font(.caption2)
                                .foregroundStyle(item.isPinned ? .orange : Color.secondary)
                                .padding(4)
                        }
                        .buttonStyle(.plain)
                        .help(item.isPinned ? "Открепить" : "Закрепить 📌")

                        Button(action: onDelete) {
                            Image(systemName: "xmark")
                                .font(.caption2)
                                .foregroundStyle(Color.secondary)
                                .padding(4)
                        }
                        .buttonStyle(.plain)
                        .help("Удалить из истории")
                    }
                }

                if item.type == .image, let img = item.thumbnailImage {
                    Image(nsImage: img)
                        .resizable()
                        .aspectRatio(contentMode: .fit)
                        .frame(maxHeight: 110)
                        .cornerRadius(6)
                        .padding(.vertical, 2)
                }

                HStack {
                    Text(timeFormatted)
                        .font(.caption2)
                        .foregroundStyle(Color.secondary)

                    Spacer()

                    Text("\(item.text.count) симв.")
                        .font(.caption2)
                        .foregroundStyle(Color.secondary.opacity(0.7))
                }
            }
            .padding(10)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isHovered ? Color(NSColor.selectedContentBackgroundColor).opacity(0.18) : Color(NSColor.controlBackgroundColor).opacity(0.6))
            )
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isHovered ? Color.blue.opacity(0.4) : Color.clear, lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
