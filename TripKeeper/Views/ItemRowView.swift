import SwiftUI

/// 时间轴上的单个行程条目卡片。
struct ItemRowView: View {
    let item: ItineraryItem

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            VStack(alignment: .trailing, spacing: 2) {
                Text(item.startTime?.hourMinute ?? "--:--")
                    .font(.subheadline.monospacedDigit().weight(.semibold))
                if let end = item.endTime {
                    Text(end.hourMinute)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 44, alignment: .trailing)

            ZStack {
                Circle()
                    .fill(item.type.color.opacity(0.15))
                    .frame(width: 34, height: 34)
                Image(systemName: item.type.icon)
                    .font(.footnote)
                    .foregroundStyle(item.type.color)
            }

            VStack(alignment: .leading, spacing: 5) {
                HStack(alignment: .firstTextBaseline) {
                    Text(item.title)
                        .font(.body.weight(.medium))
                        .lineLimit(2)
                    Spacer()
                    Text(item.type.label)
                        .font(.caption2)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(item.type.color.opacity(0.12), in: Capsule())
                        .foregroundStyle(item.type.color)
                }

                if !item.subtitle.isEmpty {
                    Text(item.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if let platformName = item.platformDisplayName, !item.orderNumber.isEmpty {
                    Text("\(platformName) · 订单 \(item.orderNumber)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .lineLimit(1)
                } else if let platformName = item.platformDisplayName {
                    Text("已在\(platformName)预订")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }

                if item.hasBookingInfo {
                    BookingActionsView(item: item)
                }
            }
        }
        .padding(.vertical, 2)
    }
}

/// 预订操作按钮行：打开App / 打开链接 / 打电话 / 复制订单号。
struct BookingActionsView: View {
    let item: ItineraryItem
    @State private var copied = false

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if let platform = item.platform, platform != .custom {
                    chip("打开\(platform.label)", icon: "arrow.up.forward.app.fill") {
                        DeepLinkService.openPlatform(platform)
                    }
                }
                if let url = item.bookingURL {
                    chip("打开链接", icon: "link") {
                        DeepLinkService.open(url)
                    }
                }
                if !item.phoneNumber.isEmpty {
                    chip("打电话", icon: "phone.fill") {
                        DeepLinkService.call(item.phoneNumber)
                    }
                }
                if !item.orderNumber.isEmpty {
                    chip(copied ? "已复制" : "复制订单号", icon: copied ? "checkmark" : "doc.on.doc") {
                        DeepLinkService.copy(item.orderNumber)
                        copied = true
                        Task {
                            try? await Task.sleep(for: .seconds(2))
                            copied = false
                        }
                    }
                }
            }
        }
        .scrollBounceBehavior(.basedOnSize)
    }

    private func chip(_ title: String, icon: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(.caption.weight(.medium))
                .padding(.horizontal, 9)
                .padding(.vertical, 5)
                .background(item.type.color.opacity(0.12), in: Capsule())
                .foregroundStyle(item.type.color)
        }
        .buttonStyle(.borderless)
    }
}
