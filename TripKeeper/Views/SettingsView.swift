import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @AppStorage(NotificationService.enabledKey) private var remindersEnabled = true
    @AppStorage(NotificationService.leadMinutesKey) private var leadMinutes = 120

    var body: some View {
        NavigationStack {
            Form {
                reminderSection
                platformSection
                aboutSection
            }
            .navigationTitle("设置")
        }
    }

    private var reminderSection: some View {
        Section {
            Toggle("航班/火车出发提醒", isOn: $remindersEnabled)
            if remindersEnabled {
                Stepper("提前 \(leadMinutes) 分钟提醒", value: $leadMinutes, in: 30...360, step: 30)
            }
        } header: {
            Text("出发提醒")
        } footer: {
            Text("对填写了开始时间的航班、火车条目发送本地通知，无需联网。")
        }
        .onChange(of: remindersEnabled) {
            reschedule()
        }
        .onChange(of: leadMinutes) {
            reschedule()
        }
    }

    private var platformSection: some View {
        Section {
            ForEach(BookingPlatform.allCases.filter { $0 != .custom }) { platform in
                HStack {
                    Text(platform.label)
                    Spacer()
                    if let scheme = platform.schemeURL {
                        Text(scheme.absoluteString)
                            .font(.caption.monospaced())
                            .foregroundStyle(.secondary)
                    }
                }
            }
        } header: {
            Text("支持跳转的预订平台")
        } footer: {
            Text("条目关联平台后，可从卡片一键唤起对应 App 修改预订；未安装时自动打开对应网页或 App Store。")
        }
    }

    private var aboutSection: some View {
        Section {
            LabeledContent("版本", value: "1.0")
            LabeledContent("数据存储", value: "仅本机（SwiftData）")
            LabeledContent("天气数据", value: "Open-Meteo")
        } header: {
            Text("关于")
        } footer: {
            Text("行程管家 TripKeeper：行程规划 · 路线优化 · 预订管理，数据不出本机。")
        }
    }

    private func reschedule() {
        Task { @MainActor in
            await NotificationService.rescheduleAll(context: context)
        }
    }
}
