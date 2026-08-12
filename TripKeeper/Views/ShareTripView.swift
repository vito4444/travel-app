import SwiftUI

/// 分享导出：文本行程单 + 行程长图。
struct ShareTripView: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss

    @State private var posterImage: Image?

    var body: some View {
        NavigationStack {
            ScrollView {
                TripPosterView(trip: trip)
                    .padding(16)
            }
            .background(Color(.systemGroupedBackground))
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    ShareLink(item: ExportService.text(for: trip)) {
                        Label("分享文本行程单", systemImage: "doc.plaintext")
                            .font(.subheadline)
                    }
                    .buttonStyle(.bordered)

                    if let posterImage {
                        ShareLink(
                            item: posterImage,
                            preview: SharePreview("\(trip.name) 行程长图", image: posterImage)
                        ) {
                            Label("分享长图", systemImage: "square.and.arrow.up")
                                .font(.subheadline)
                        }
                        .buttonStyle(.borderedProminent)
                    } else {
                        Button {
                            renderPoster()
                        } label: {
                            Label("生成长图", systemImage: "photo.badge.arrow.down")
                                .font(.subheadline)
                        }
                        .buttonStyle(.borderedProminent)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)
                .frame(maxWidth: .infinity)
                .background(.bar)
            }
            .navigationTitle("分享行程")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    @MainActor
    private func renderPoster() {
        let renderer = ImageRenderer(
            content: TripPosterView(trip: trip)
                .frame(width: 420)
                .environment(\.colorScheme, .light)
        )
        renderer.scale = 3
        if let uiImage = renderer.uiImage {
            posterImage = Image(uiImage: uiImage)
        }
    }
}

/// 行程长图（固定浅色，供渲染导出与预览）。
struct TripPosterView: View {
    let trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
            ForEach(0..<trip.dayCount, id: \.self) { day in
                daySection(day)
            }
            footer
        }
        .background(.white)
        .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(trip.name)
                .font(.title2.bold())
                .foregroundStyle(.white)
            HStack(spacing: 8) {
                if !trip.destination.isEmpty {
                    Label(trip.destination, systemImage: "mappin.circle.fill")
                }
                Text("\(trip.startDate.monthDayZH) - \(trip.endDate.monthDayZH) · \(trip.dayCount)天")
            }
            .font(.footnote)
            .foregroundStyle(.white.opacity(0.92))
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(hex: trip.colorHex), Color(hex: trip.colorHex).opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
    }

    private func daySection(_ day: Int) -> some View {
        let date = trip.date(forDay: day)
        let items = trip.items(forDay: day)
        return VStack(alignment: .leading, spacing: 8) {
            Text("第\(day + 1)天 · \(date.monthDayZH) \(date.weekdayZH)")
                .font(.subheadline.bold())
                .foregroundStyle(Color(hex: trip.colorHex))
            if items.isEmpty {
                Text("暂无安排")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            ForEach(items) { item in
                HStack(alignment: .top, spacing: 8) {
                    Text(item.startTime?.hourMinute ?? "--:--")
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                        .frame(width: 40, alignment: .trailing)
                    Image(systemName: item.type.icon)
                        .font(.caption)
                        .foregroundStyle(item.type.color)
                        .frame(width: 16)
                    VStack(alignment: .leading, spacing: 2) {
                        Text(item.title)
                            .font(.footnote.weight(.medium))
                            .foregroundStyle(.black)
                        if !item.subtitle.isEmpty {
                            Text(item.subtitle)
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private var footer: some View {
        Text("—— 行程管家 TripKeeper ——")
            .font(.caption2)
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 12)
    }
}
