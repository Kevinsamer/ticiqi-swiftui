//  Settings sheet — bottom sheet for configuring teleprompter defaults
//  ticiqi
//

import SwiftUI

struct SettingsSheetView: View {
    @Binding var settings: PrompterSettings
    @Environment(\.dismiss) private var dismiss
    @State private var saveTask: Task<Void, Never>?

    var body: some View {
        NavigationStack {
            Form {
                scrollSection
                textSection
                displaySection
                networkSection
            }
            .navigationTitle("提词器设置")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
            .onChange(of: settings) { _, newValue in
                saveTask?.cancel()
                saveTask = Task {
                    try? await Task.sleep(for: .milliseconds(500))
                    guard !Task.isCancelled else { return }
                    newValue.save()
                }
            }
            .onDisappear {
                saveTask?.cancel()
                settings.save()
            }
        }
        .presentationDetents([.medium, .large])
        .presentationDragIndicator(.visible)
    }

    // MARK: - Scroll section

    private var scrollSection: some View {
        Section("滚动") {
            HStack {
                Text("默认速度")
                Spacer()
                Text("\(Int(settings.defaultSpeed))")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $settings.defaultSpeed, in: 1...200, step: 1)

            Picker("滚动方向", selection: $settings.scrollDirection) {
                Text("向上").tag(ScrollDirection.up)
                Text("向下").tag(ScrollDirection.down)
            }
            .pickerStyle(.segmented)
        }
    }

    // MARK: - Text section

    private var textSection: some View {
        Section("文字") {
            HStack {
                Text("字号")
                Spacer()
                Text("\(Int(settings.fontSize))")
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            Slider(value: $settings.fontSize, in: 20...120, step: 2)

            ColorPicker("文字颜色", selection: Binding(
                get: { settings.textColor },
                set: { settings.textColor = $0 }
            ))

            VStack(alignment: .leading, spacing: 8) {
                Text("背景色")
                HStack(spacing: 12) {
                    ForEach(BackgroundOption.allCases, id: \.self) { option in
                        RoundedRectangle(cornerRadius: 8)
                            .fill(option.color)
                            .frame(width: 48, height: 32)
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.gray,
                                        lineWidth: settings.backgroundColor == option ? 3 : 0)
                            )
                            .onTapGesture { settings.backgroundColor = option }
                    }
                }
            }
            .padding(.vertical, 4)
        }
    }

    // MARK: - Display section

    private var displaySection: some View {
        Section("显示选项") {
            Toggle("镜像模式", isOn: $settings.mirrorEnabled)
            Toggle("焦点线", isOn: $settings.focusLineEnabled)
        }
    }

    // MARK: - Network section

    private var networkSection: some View {
        Section("网络") {
            Toggle("自动启动控制服务", isOn: $settings.autoStartServer)
        }
    }
}
