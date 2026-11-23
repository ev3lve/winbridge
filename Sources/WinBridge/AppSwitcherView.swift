import SwiftUI

struct AppSwitcherView: View {
    @ObservedObject private var controller = AppSwitcherController.shared

    var body: some View {
        VStack(spacing: 12) {
            // Список запущенных приложений в стиле Windows 11
            ScrollViewReader { proxy in
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 12) {
                        ForEach(Array(controller.items.enumerated()), id: \.element.id) { index, item in
                            let isSelected = (index == controller.selectedIndex)

                            Button(action: {
                                controller.selectAndCommit(index: index)
                            }) {
                                VStack(spacing: 8) {
                                    // Иконка приложения
                                    Image(nsImage: item.icon)
                                        .resizable()
                                        .interpolation(.high)
                                        .aspectRatio(contentMode: .fit)
                                        .frame(width: 52, height: 52)
                                        .shadow(color: .black.opacity(0.35), radius: 4, x: 0, y: 2)

                                    // Название приложения
                                    Text(item.name)
                                        .font(.system(size: 13, weight: isSelected ? .bold : .medium))
                                        .foregroundColor(isSelected ? .white : .white.opacity(0.85))
                                        .lineLimit(1)
                                        .frame(maxWidth: 100)

                                    // Название окна (если есть)
                                    if !item.windowTitle.isEmpty {
                                        Text(item.windowTitle)
                                            .font(.system(size: 10))
                                            .foregroundColor(.white.opacity(0.6))
                                            .lineLimit(1)
                                            .frame(maxWidth: 100)
                                    } else {
                                        Text(" ")
                                            .font(.system(size: 10))
                                    }
                                }
                                .padding(.vertical, 14)
                                .padding(.horizontal, 10)
                                .frame(width: 110, height: 130)
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .fill(isSelected ? Color.white.opacity(0.18) : Color.white.opacity(0.04))
                                )
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .strokeBorder(
                                            isSelected ? Color(red: 0.0, green: 0.47, blue: 0.83) : Color.white.opacity(0.08),
                                            lineWidth: isSelected ? 2.5 : 1
                                        )
                                )
                                .scaleEffect(isSelected ? 1.05 : 1.0)
                                .animation(.spring(response: 0.25, dampingFraction: 0.8), value: isSelected)
                            }
                            .buttonStyle(.plain)
                            .id(index)
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                }
                .onChange(of: controller.selectedIndex) { newIndex in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        proxy.scrollTo(newIndex, anchor: .center)
                    }
                }
            }

            // Подсказка управления
            HStack(spacing: 8) {
                Text("Нажмите")
                    .foregroundColor(.white.opacity(0.5))
                Text("Tab")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(4)
                    .foregroundColor(.white.opacity(0.9))
                Text("для выбора • Отпустите")
                    .foregroundColor(.white.opacity(0.5))
                Text("Alt")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(4)
                    .foregroundColor(.white.opacity(0.9))
                Text("для перехода •")
                    .foregroundColor(.white.opacity(0.5))
                Text("Esc")
                    .font(.system(size: 10, weight: .bold))
                    .padding(.horizontal, 6)
                    .padding(.vertical, 2)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(4)
                    .foregroundColor(.white.opacity(0.9))
                Text("отмена")
                    .foregroundColor(.white.opacity(0.5))
            }
            .font(.system(size: 11))
            .padding(.bottom, 6)
        }
        .padding(.vertical, 12)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(
            ZStack {
                VisualEffectBackground()
                Color.black.opacity(0.55)
            }
        )
        .cornerRadius(18)
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(Color.white.opacity(0.2), lineWidth: 1)
        )
        .shadow(color: .black.opacity(0.6), radius: 24, x: 0, y: 12)
    }
}
