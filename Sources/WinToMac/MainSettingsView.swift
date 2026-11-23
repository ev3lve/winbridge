import SwiftUI

struct MainSettingsView: View {
    @ObservedObject var settings = AppSettings.shared
    @ObservedObject var clipboard = ClipboardManager.shared

    var body: some View {
        VStack(spacing: 0) {
            // Заголовок
            HStack {
                Image(systemName: "keyboard.badge.ellipsis")
                    .font(.title2)
                    .foregroundStyle(.blue)
                VStack(alignment: .leading, spacing: 2) {
                    Text("WinToMac")
                        .font(.headline)
                        .fontWeight(.bold)
                    Text("Виндовые привычки на Mac")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button(action: {
                    NSApplication.shared.terminate(nil)
                }) {
                    Image(systemName: "power")
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
                .help("Закрыть WinToMac")
            }
            .padding()
            .background(Color(NSColor.windowBackgroundColor))

            Divider()

            // Кнопка открытия главного окна
            Button(action: {
                MainWindowController.shared.show()
            }) {
                HStack {
                    Image(systemName: "macwindow.on.rectangle")
                        .foregroundStyle(.blue)
                    Text("Открыть главное окно")
                        .fontWeight(.semibold)
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color.blue.opacity(0.12))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .padding(.horizontal, 14)
            .padding(.top, 10)

            ScrollView {
                VStack(spacing: 14) {
                    // Статус доступа
                    if settings.isAccessibilityGranted {
                        HStack {
                            Image(systemName: "checkmark.seal.fill")
                                .foregroundStyle(.green)
                            Text("Универсальный доступ активен")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            Spacer()
                        }
                        .padding(10)
                        .background(Color.green.opacity(0.12))
                        .cornerRadius(8)
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundStyle(.orange)
                                Text("Требуется разрешение!")
                                    .font(.subheadline)
                                    .fontWeight(.bold)
                            }
                            Text("Для перехвата горячих клавиш включите тумблер в Системных настройках.")
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            Button("Открыть Системные настройки") {
                                settings.openAccessibilitySettings()
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                        }
                        .padding(10)
                        .background(Color.orange.opacity(0.12))
                        .cornerRadius(8)
                    }

                    // Секция: Буфер обмена (Win + V)
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Буфер обмена (Win + V)")
                                .font(.caption)
                                .fontWeight(.bold)
                                .foregroundStyle(.secondary)
                                .textCase(.uppercase)
                            Spacer()
                            Text("\(clipboard.items.count) скопировано")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }

                        Toggle(isOn: $settings.isClipboardHistoryEnabled) {
                            VStack(alignment: .leading) {
                                Text("История буфера (Win + V)")
                                    .fontWeight(.medium)
                                Text("Всплывающее окно со всеми скопированными текстами")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                        }

                        Button(action: {
                            ClipboardWindowController.shared.show()
                        }) {
                            HStack {
                                Image(systemName: "doc.on.clipboard")
                                Text("Показать историю буфера")
                                Spacer()
                                Text("Win + V")
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)

                    // Секция: Быстрые тумблеры
                    VStack(alignment: .leading, spacing: 10) {
                        Text("Основные бинды")
                            .font(.caption)
                            .fontWeight(.bold)
                            .foregroundStyle(.secondary)
                            .textCase(.uppercase)

                        Toggle(isOn: $settings.isAltShiftSwitchEnabled) {
                            Text("Смена языка по Alt + Shift")
                                .fontWeight(.medium)
                        }

                        Toggle(isOn: $settings.isCtrlBackspaceEnabled) {
                            Text("Виндовый Ctrl + Backspace")
                                .fontWeight(.medium)
                        }

                        Toggle(isOn: $settings.isWindowSnapEnabled) {
                            Text("Snap окон (Win + Стрелки)")
                                .fontWeight(.medium)
                        }

                        Toggle(isOn: $settings.isWindowsMouseScrollEnabled) {
                            Text("Виндовый скролл мыши")
                                .fontWeight(.medium)
                        }

                        Toggle(isOn: $settings.isGlobalShortcutsEnabled) {
                            Text("Win + E, Win + D, Win + L")
                                .fontWeight(.medium)
                        }
                    }
                    .padding(12)
                    .background(Color(NSColor.controlBackgroundColor))
                    .cornerRadius(10)
                }
                .padding(14)
            }

            Divider()

            // Подвал
            HStack {
                Text("Версия 2.0 (Dual UI)")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                Spacer()
                Button("Выход") {
                    NSApplication.shared.terminate(nil)
                }
                .buttonStyle(.plain)
                .font(.caption)
                .foregroundStyle(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(NSColor.windowBackgroundColor))
        }
        .frame(width: 320, height: 530)
    }
}
