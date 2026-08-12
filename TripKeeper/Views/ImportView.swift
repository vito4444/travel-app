import SwiftUI
import SwiftData

/// 粘贴订票短信/确认文本，离线解析生成行程条目。
struct ImportView: View {
    let trip: Trip
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    @State private var text = ""
    @State private var parsed: ParsedBooking?
    @State private var parseFailed = false
    @State private var targetDay = 0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextEditor(text: $text)
                        .frame(minHeight: 120)
                        .font(.callout)
                    HStack(spacing: 8) {
                        sampleButton("火车票示例", BookingSampleTexts.train)
                        sampleButton("航班示例", BookingSampleTexts.flight)
                        sampleButton("酒店示例", BookingSampleTexts.hotel)
                    }
                } header: {
                    Text("粘贴订票短信 / 确认信息")
                } footer: {
                    Text("支持 12306 购票短信、平台的航班/酒店确认短信，本机离线解析，不上传任何内容。")
                }

                Section {
                    Button {
                        parse()
                    } label: {
                        Label("解析", systemImage: "wand.and.rays")
                    }
                    .disabled(text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if parseFailed {
                        Text("未能识别这段文本。目前支持含车次/航班号/酒店名的确认信息，也可以手动添加条目。")
                            .font(.caption)
                            .foregroundStyle(.orange)
                    }
                }

                if let parsed {
                    parsedSection(parsed)
                }
            }
            .navigationTitle("智能导入")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("关闭") { dismiss() }
                }
            }
        }
    }

    private func sampleButton(_ title: String, _ sample: String) -> some View {
        Button(title) {
            text = sample
            parsed = nil
            parseFailed = false
        }
        .font(.caption)
        .buttonStyle(.bordered)
    }

    private func parsedSection(_ parsed: ParsedBooking) -> some View {
        Section("解析结果") {
            LabeledContent("类型", value: parsed.type.label)
            LabeledContent("标题", value: parsed.title)
            if !parsed.transportNumber.isEmpty {
                LabeledContent(parsed.type == .flight ? "航班号" : "车次", value: parsed.transportNumber)
            }
            if !parsed.departurePlace.isEmpty || !parsed.arrivalPlace.isEmpty {
                LabeledContent("路线", value: [parsed.departurePlace, parsed.arrivalPlace].filter { !$0.isEmpty }.joined(separator: " → "))
            }
            if let month = parsed.month, let day = parsed.day {
                let timePart: String = {
                    if let hour = parsed.hour, let minute = parsed.minute {
                        return String(format: " %02d:%02d", hour, minute)
                    }
                    return ""
                }()
                LabeledContent(parsed.type == .hotel ? "入住" : "出发", value: "\(month)月\(day)日\(timePart)")
            }
            if let checkOutMonth = parsed.checkOutMonth, let checkOutDay = parsed.checkOutDay {
                LabeledContent("退房", value: "\(checkOutMonth)月\(checkOutDay)日")
            }
            if !parsed.orderNumber.isEmpty {
                LabeledContent("订单号", value: parsed.orderNumber)
            }
            if !parsed.phoneNumber.isEmpty {
                LabeledContent("电话", value: parsed.phoneNumber)
            }
            if let platform = parsed.platform {
                LabeledContent("平台", value: platform.label)
            }

            Picker("添加到", selection: $targetDay) {
                ForEach(0..<trip.dayCount, id: \.self) { day in
                    Text("第\(day + 1)天 · \(trip.date(forDay: day).monthDayZH)").tag(day)
                }
            }

            Button {
                add(parsed)
            } label: {
                Label("添加到行程", systemImage: "plus.circle.fill")
            }
        }
    }

    // MARK: - 逻辑

    private func parse() {
        let result = BookingTextParser.parse(text)
        parsed = result
        parseFailed = result == nil
        if let result {
            targetDay = suggestedDay(for: result)
        }
    }

    /// 按解析出的月日推断落在行程第几天；不在行程范围内则回第 1 天。
    private func suggestedDay(for parsed: ParsedBooking) -> Int {
        guard let month = parsed.month, let day = parsed.day,
              let date = resolveDate(month: month, day: day) else { return 0 }
        let index = trip.startDate.daysUntil(date)
        guard index >= 0, index < trip.dayCount else { return 0 }
        return index
    }

    /// 用行程年份补全月日；若落在行程开始 180 天前，则视为跨年往后推一年。
    private func resolveDate(month: Int, day: Int) -> Date? {
        let calendar = Calendar.current
        var comps = calendar.dateComponents([.year], from: trip.startDate)
        comps.month = month
        comps.day = day
        guard let candidate = calendar.date(from: comps) else { return nil }
        if candidate < trip.startDate.startOfDay,
           trip.startDate.startOfDay.timeIntervalSince(candidate) > 180 * 86_400,
           let nextYear = calendar.date(byAdding: .year, value: 1, to: candidate) {
            return nextYear
        }
        return candidate
    }

    private func add(_ parsed: ParsedBooking) {
        let sortIndex = (trip.items(forDay: targetDay).map(\.sortIndex).max() ?? -1) + 1
        let item = ItineraryItem(title: parsed.title, type: parsed.type, dayIndex: targetDay, sortIndex: sortIndex)
        item.trip = trip
        item.transportNumber = parsed.transportNumber
        item.departurePlace = parsed.departurePlace
        item.arrivalPlace = parsed.arrivalPlace
        item.orderNumber = parsed.orderNumber
        item.phoneNumber = parsed.phoneNumber
        item.platformRaw = parsed.platform?.rawValue ?? ""
        item.notes = parsed.extraNote

        if let hour = parsed.hour, let minute = parsed.minute {
            let dayDate = trip.date(forDay: targetDay)
            item.startTime = Calendar.current.date(bySettingHour: hour, minute: minute, second: 0, of: dayDate)
        }
        if parsed.type == .hotel {
            if let month = parsed.month, let day = parsed.day {
                item.checkInDate = resolveDate(month: month, day: day)
            }
            if let month = parsed.checkOutMonth, let day = parsed.checkOutDay {
                item.checkOutDate = resolveDate(month: month, day: day)
            }
        }

        context.insert(item)
        dismiss()
        Task { @MainActor in
            await NotificationService.rescheduleAll(context: context)
        }
    }
}
