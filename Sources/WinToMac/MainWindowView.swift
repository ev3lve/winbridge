import SwiftUI

enum MainTab: String, CaseIterable, Identifiable {
    case dashboard = "Обзор"
    case keyboard = "Клавиатура"
    case finder = "Проводник"
    case clipboard = "Буфер обмена"
    case mouse = "Мышь и скролл"
    case settings = "Настройки"

    var id: String { rawValue }

    var iconName: String {
        switch self {
        case .dashboard: return "sparkles"
        case .keyboard: return "keyboard"
        case .finder: return "folder"
        case .clipboard: return "doc.on.clipboard"
        case .mouse: return "computermouse"
        case .settings: return "gearshape"
        }
    }
}

struct MainWindowView: View {
    @State private var selectedTab: MainTab = .dashboard
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        NavigationSplitView {
            // Сайдбар
            List(MainTab.allCases, selection: $selectedTab) { tab in
                NavigationLink(value: tab) {
                    Label(tab.rawValue, systemImage: tab.iconName)
                        .font(.headline)
                        .padding(.vertical, 4)
                }
            }
            .navigationSplitViewColumnWidth(min: 190, ideal: 210, max: 240)
            .listStyle(.sidebar)
            .safeAreaInset(edge: .bottom) {
                // Статус внизу сайдбара
                HStack(spacing: 8) {
                    Circle()
                        .fill(settings.isAccessibilityGranted ? Color.green : Color.orange)
                        .frame(width: 9, height: 9)
                    Text(settings.isAccessibilityGranted ? "Служба активна" : "Требует доступ")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(12)
                .background(Color(NSColor.windowBackgroundColor).opacity(0.6))
            }
        } detail: {
            Group {
                switch selectedTab {
                case .dashboard:
                    DashboardTabView()
                case .keyboard:
                    KeyboardTabView()
                case .finder:
                    FinderTabView()
                case .clipboard:
                    ClipboardFullTabView()
                case .mouse:
                    MouseTabView()
                case .settings:
                    SettingsTabView()
                }
            }
            .frame(minWidth: 540, minHeight: 520)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(minWidth: 760, minHeight: 540)
    }
}

// MARK: - 1. Главная вкладка (Обзор)
struct DashboardTabView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var clipboard = ClipboardManager.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Приветственный баннер
                VStack(alignment: .leading, spacing: 6) {
                    HStack {
                        Image(systemName: "hand.wave.fill")
                            .foregroundStyle(.yellow)
                        Text("Добро пожаловать в WinToMac!")
                            .font(.title2)
                            .fontWeight(.bold)
                    }
                    Text("Все привычные привычки и сочетания клавиш из Windows теперь работают нативно в macOS.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(
                    RoundedRectangle(cornerRadius: 12)
                        .fill(LinearGradient(colors: [Color.blue.opacity(0.12), Color.purple.opacity(0.06)], startPoint: .topLeading, endPoint: .bottomTrailing))
                )

                // Карточки быстрого статуса
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 14) {
                    StatusCard(
                        icon: "keyboard.fill",
                        color: .blue,
                        title: "Смена языка",
                        value: "Alt + Shift",
                        subtitle: settings.isAltShiftSwitchEnabled ? "Включено" : "Отключено"
                    )

                    StatusCard(
                        icon: "doc.on.clipboard.fill",
                        color: .green,
                        title: "Буфер обмена",
                        value: "\(clipboard.items.count) записей",
                        subtitle: "Вызов: Win + V"
                    )

                    StatusCard(
                        icon: "macwindow.on.rectangle",
                        color: .purple,
                        title: "Snap окон",
                        value: "Win + Стрелки",
                        subtitle: settings.isWindowSnapEnabled ? "Влево / Вправо / Maximize" : "Отключено"
                    )

                    StatusCard(
                        icon: "delete.left.fill",
                        color: .orange,
                        title: "Ctrl + Backspace",
                        value: "По словам",
                        subtitle: "Стирает 1 слово везде"
                    )
                }

                // Быстрые действия
                VStack(alignment: .leading, spacing: 12) {
                    Text("Быстрые действия")
                        .font(.headline)

                    HStack(spacing: 12) {
                        Button(action: {
                            ClipboardWindowController.shared.show()
                        }) {
                            Label("Открыть буфер (Win + V)", systemImage: "doc.on.clipboard")
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.borderedProminent)

                        Button(action: {
                            WindowManager.shared.openFinder()
                        }) {
                            Label("Открыть Проводник (Win + E)", systemImage: "folder")
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.bordered)

                        Button(action: {
                            WindowManager.shared.openActivityMonitor()
                        }) {
                            Label("Диспетчер задач", systemImage: "chart.bar.xaxis")
                                .padding(.vertical, 4)
                        }
                        .buttonStyle(.bordered)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }
            .padding(24)
        }
    }
}

struct StatusCard: View {
    let icon: String
    let color: Color
    let title: String
    let value: String
    let subtitle: String

    var body: some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title)
                .foregroundStyle(color)
                .frame(width: 44, height: 44)
                .background(color.opacity(0.12))
                .cornerRadius(10)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(value)
                    .font(.headline)
                    .fontWeight(.bold)
                Text(subtitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(14)
        .background(Color(NSColor.controlBackgroundColor))
        .cornerRadius(12)
    }
}

// MARK: - 2. Вкладка Клавиатура
struct KeyboardTabView: View {
    @ObservedObject var settings = AppSettings.shared
    @State private var testText = "Напишите тут текст и нажмите Ctrl + Backspace для проверки!"

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Клавиатура и горячие клавиши")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Настройка поведения клавиш и виндовых шорткатов.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                // Секция: Смена языка и текст
                VStack(spacing: 14) {
                    ToggleRow(
                        title: "Смена языка на Alt + Shift (и Ctrl + Shift)",
                        subtitle: "Мгновенное переключение раскладки как на Windows (ABC ⇄ Рус ⇄ Укр)",
                        isOn: $settings.isAltShiftSwitchEnabled
                    )

                    Divider()

                    ToggleRow(
                        title: "Виндовый Ctrl + Backspace",
                        subtitle: "Стирает ровно одно слово назад вместо всей строки (Chrome, Discord, VS Code, Safari)",
                        isOn: $settings.isCtrlBackspaceEnabled
                    )

                    Divider()

                    ToggleRow(
                        title: "Ctrl + Стрелки (навигация по словам)",
                        subtitle: "Прыжки курсора и выделение текста по словам (Ctrl + Shift + Стрелки)",
                        isOn: $settings.isWordJumpEnabled
                    )

                    Divider()

                    ToggleRow(
                        title: "Клавиши Home и End",
                        subtitle: "Перемещение курсора в начало и конец строки (а с Ctrl — в начало и конец документа)",
                        isOn: $settings.isHomeEndEnabled
                    )

                    Divider()

                    ToggleRow(
                        title: "Win + Shift + S (Ножницы скриншота)",
                        subtitle: "Интерактивное выделение области экрана прямо в буфер обмена",
                        isOn: $settings.isScreenshotEnabled
                    )
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

                // Секция: Глобальные шорткаты Windows
                VStack(alignment: .leading, spacing: 14) {
                    Text("Глобальные системные шорткаты")
                        .font(.headline)

                    ToggleRow(
                        title: "Виндовый Snap окон (Win + Стрелки)",
                        subtitle: "Win + Влево/Вправо (половина экрана), Win + Вверх (Maximize), Win + Вниз (Restore)",
                        isOn: $settings.isWindowSnapEnabled
                    )

                    Divider()

                    ToggleRow(
                        title: "Win + E, Win + D, Win + L, Ctrl + Shift + Esc",
                        subtitle: "Win+E (Проводник), Win+D (Рабочий стол), Win+L (Блокировка экрана), Ctrl+Shift+Esc (Диспетчер задач)",
                        isOn: $settings.isGlobalShortcutsEnabled
                    )

                    Divider()

                    ToggleRow(
                        title: "Закрытие программ по Alt + F4",
                        subtitle: "Полное и честное завершение активного приложения как в Windows (вместо маковского Cmd+Q)",
                        isOn: $settings.isAltF4Enabled
                    )
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

                // Поле для теста
                VStack(alignment: .leading, spacing: 8) {
                    Text("Поле для проверки биндов:")
                        .font(.caption)
                        .fontWeight(.bold)
                        .foregroundStyle(.secondary)
                    TextField("Тест текста...", text: $testText)
                        .textFieldStyle(.roundedBorder)
                }
                .padding()
                .background(Color.blue.opacity(0.06))
                .cornerRadius(10)
            }
            .padding(24)
        }
    }
}

// MARK: - 3. Вкладка Проводник (Finder)
struct FinderTabView: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Проводник (Finder)")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Исправление поведения файлов и навигации в стиле Windows Explorer.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 14) {
                    ToggleRow(
                        title: "Enter открывает, F2 переименовывает",
                        subtitle: "В macOS по умолчанию Enter переименовывает файл. Мы возвращаем виндовый Enter (открыть) и F2 (переименовать)",
                        isOn: $settings.isFinderFixEnabled
                    )

                    Divider()

                    ToggleRow(
                        title: "Клавиша Delete удаляет в корзину",
                        subtitle: "Нажатие Del на клавиатуре сразу отправляет выбранный файл в корзину (вместо Cmd+Delete)",
                        isOn: $settings.isFinderExtrasEnabled
                    )

                    Divider()

                    ToggleRow(
                        title: "Backspace возвращает на папку выше",
                        subtitle: "Переход на уровень вверх по папкам по клавише Backspace, как в проводнике Windows",
                        isOn: $settings.isFinderExtrasEnabled
                    )

                    Divider()

                    ToggleRow(
                        title: "Ctrl + H — показать/скрыть скрытые файлы",
                        subtitle: "Быстрое переключение отображения скрытых файлов и папок с точкой",
                        isOn: $settings.isFinderExtrasEnabled
                    )
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

                Button(action: {
                    WindowManager.shared.openFinder()
                }) {
                    Label("Открыть Finder прямо сейчас", systemImage: "folder")
                        .padding(.vertical, 4)
                }
                .buttonStyle(.borderedProminent)
            }
            .padding(24)
        }
    }
}

// MARK: - 4. Вкладка Буфер обмена (Полноценный менеджер)
struct ClipboardFullTabView: View {
    @ObservedObject var manager = ClipboardManager.shared
    @State private var searchText = ""
    @State private var selectedItem: ClipboardItem?

    var filteredItems: [ClipboardItem] {
        if searchText.isEmpty {
            return manager.items
        } else {
            return manager.items.filter { $0.text.localizedCaseInsensitiveContains(searchText) }
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Верхняя панель управления
            HStack {
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundStyle(.secondary)
                    TextField("Поиск по истории буфера...", text: $searchText)
                        .textFieldStyle(.plain)
                    if !searchText.isEmpty {
                        Button(action: { searchText = "" }) {
                            Image(systemName: "xmark.circle.fill")
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(8)
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(8)

                Spacer()

                Button("Очистить историю") {
                    manager.clearAll()
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button("Вызов: Win + V") {
                    ClipboardWindowController.shared.show()
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
            .padding(16)
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            HSplitView {
                // Список слева
                List(filteredItems, selection: $selectedItem) { item in
                    HStack(alignment: .top, spacing: 10) {
                        if item.isPinned {
                            Image(systemName: "pin.fill")
                                .font(.caption)
                                .foregroundStyle(.orange)
                                .padding(.top, 2)
                        }

                        if item.type == .image {
                            Image(systemName: "photo.fill")
                                .font(.caption)
                                .foregroundStyle(.blue)
                                .padding(.top, 2)
                        }

                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.text)
                                .font(.subheadline)
                                .lineLimit(2)
                                .foregroundStyle(Color.primary)
                            Text(item.date.formatted(date: .omitted, time: .shortened))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Spacer()
                    }
                    .padding(.vertical, 4)
                    .tag(item)
                    .contextMenu {
                        Button("Скопировать") { manager.copyToClipboard(item: item) }
                        Button(item.isPinned ? "Открепить" : "Закрепить на булавку 📌") { manager.togglePin(item: item) }
                        Divider()
                        Button("Удалить", role: .destructive) { manager.delete(item: item) }
                    }
                }
                .frame(minWidth: 260)

                // Детальный просмотр справа
                VStack(alignment: .leading, spacing: 12) {
                    if let item = selectedItem {
                        HStack {
                            Text("Сниппет от \(item.date.formatted(date: .abbreviated, time: .shortened))")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button(item.isPinned ? "Закреплено 📌" : "Закрепить") {
                                manager.togglePin(item: item)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)

                            Button("Скопировать") {
                                manager.copyToClipboard(item: item)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }

                        Divider()

                        if item.type == .image, let img = item.thumbnailImage {
                            ScrollView {
                                Image(nsImage: img)
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                                    .cornerRadius(8)
                                    .shadow(color: .black.opacity(0.15), radius: 6)
                                    .padding()
                            }
                        } else {
                            ScrollView {
                                Text(item.text)
                                    .font(.system(.body, design: .monospaced))
                                    .textSelection(.enabled)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }

                        HStack {
                            Text("\(item.text.count) символов")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                            Spacer()
                            Button("Удалить", role: .destructive) {
                                manager.delete(item: item)
                                selectedItem = nil
                            }
                            .buttonStyle(.plain)
                            .foregroundStyle(.red)
                            .font(.caption)
                        }
                    } else {
                        VStack(spacing: 12) {
                            Spacer()
                            Image(systemName: "doc.text.magnifyingglass")
                                .font(.system(size: 40))
                                .foregroundStyle(.secondary.opacity(0.5))
                            Text("Выберите запись слева для просмотра")
                                .font(.subheadline)
                                .foregroundStyle(.secondary)
                            Spacer()
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    }
                }
                .padding(16)
                .frame(minWidth: 280)
            }
        }
    }
}

// MARK: - 5. Вкладка Мышь и скролл
struct MouseTabView: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Мышь и скролл")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Раздельный скролл колесика и настройка ускорения курсора.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 14) {
                    ToggleRow(
                        title: "Раздельный скролл колесика мыши (Windows Scroll)",
                        subtitle: "Инвертирует направление прокрутки колесика мыши на привычное виндовое, НЕ ломая естественный жест на тачпаде",
                        isOn: $settings.isWindowsMouseScrollEnabled
                    )

                    Divider()

                    ToggleRow(
                        title: "Линейная мышь (отключить акселерацию)",
                        subtitle: "Отключает маковское нелинейное ускорение мыши. Движение курсора становится точным 1:1, как в шутерах и на Windows",
                        isOn: $settings.isLinearMouseEnabled
                    )
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)
            }
            .padding(24)
        }
    }
}

// MARK: - 6. Вкладка Настройки
struct SettingsTabView: View {
    @ObservedObject var settings = AppSettings.shared

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Настройки системы")
                        .font(.title2)
                        .fontWeight(.bold)
                    Text("Управление автозапуском, отображением и разрешениями.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 14) {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Запуск при входе в систему")
                                .font(.headline)
                            Text("Автоматически стартовать WinToMac при включении компьютера")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { settings.isLaunchAtLoginEnabled },
                            set: { _ in settings.toggleLaunchAtLogin() }
                        ))
                        .toggleStyle(.switch)
                    }

                    Divider()

                    ToggleRow(
                        title: "Показывать значок в панели Dock",
                        subtitle: "Если выключить — программа будет жить только в строке меню (трее) возле часов",
                        isOn: $settings.isShowInDockEnabled
                    )

                    Divider()

                    ToggleRow(
                        title: "Скрывать значок из Dock при закрытии окна",
                        subtitle: "При нажатии на крестик иконка сразу улетает из Dock, оставляя программу работать в фоне в трее",
                        isOn: $settings.isAutoHideFromDockOnClose
                    )

                    Divider()

                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text("Универсальный доступ (Accessibility)")
                                .font(.headline)
                            Text(settings.isAccessibilityGranted ? "Разрешение выдано, перехватчик работает" : "Требуется включить тумблер в Системных настройках")
                                .font(.caption)
                                .foregroundStyle(settings.isAccessibilityGranted ? .green : .orange)
                        }
                        Spacer()
                        Button("Настройки macOS") {
                            settings.openAccessibilitySettings()
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

                // Сброс настроек
                VStack(alignment: .leading, spacing: 10) {
                    Text("Сброс параметров")
                        .font(.headline)
                    Text("Если что-то настроили не так — можно вернуть все параметры в идеальное состояние по умолчанию.")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    Button("Сбросить все настройки по умолчанию") {
                        settings.resetToDefaults()
                    }
                    .buttonStyle(.bordered)
                    .foregroundStyle(.red)
                }
                .padding()
                .background(Color(NSColor.controlBackgroundColor))
                .cornerRadius(12)

                // Информация о системе
                VStack(alignment: .leading, spacing: 6) {
                    Text("WinToMac v2.0")
                        .font(.caption)
                        .fontWeight(.bold)
                    Text("Специально разработано для Ryzen 7 5700 + RTX 3050 (macOS Tahoe 26.7.3). Open Source Swift & SwiftUI.")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 4)
            }
            .padding(24)
        }
    }
}

// Вспомогательный ряд для переключателей
struct ToggleRow: View {
    let title: String
    let subtitle: String
    @Binding var isOn: Bool

    var body: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.headline)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Toggle("", isOn: $isOn)
                .toggleStyle(.switch)
        }
    }
}
