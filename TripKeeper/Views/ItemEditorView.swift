import SwiftUI
import SwiftData
import PhotosUI
import UIKit

/// 新建（existing == nil）或编辑行程条目，表单字段随类型变化。
struct ItemEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var context

    let trip: Trip
    let existing: ItineraryItem?
    let defaultDay: Int

    @State private var type: ItemType = .attraction
    @State private var title = ""
    @State private var dayIndex = 0
    @State private var hasStartTime = false
    @State private var startTime = Date()
    @State private var hasEndTime = false
    @State private var endTime = Date()
    @State private var locationName = ""
    @State private var address = ""
    @State private var latitude: Double?
    @State private var longitude: Double?
    @State private var notes = ""
    @State private var priceText = ""

    // 点对点交通
    @State private var transportNumber = ""
    @State private var departurePlace = ""
    @State private var arrivalPlace = ""

    // 酒店
    @State private var hasHotelDates = false
    @State private var checkInDate = Date()
    @State private var checkOutDate = Date()

    // 预订信息
    @State private var platformSelection = ""
    @State private var customPlatformName = ""
    @State private var orderNumber = ""
    @State private var phoneNumber = ""
    @State private var bookingURLString = ""

    // 附件
    @State private var pickerItems: [PhotosPickerItem] = []
    @State private var pendingImages: [Data] = []

    @State private var showLocationSearch = false
    @State private var loaded = false

    var body: some View {
        NavigationStack {
            Form {
                typeSection
                basicSection
                locationSection
                typeSpecificSection
                bookingSection
                attachmentSection
                notesSection
                if existing != nil {
                    deleteSection
                }
            }
            .navigationTitle(existing == nil ? "添加安排" : "编辑安排")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") { save() }
                        .disabled(title.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
            .sheet(isPresented: $showLocationSearch) {
                LocationSearchView(initialQuery: locationName.isEmpty ? title : locationName) { mapItem in
                    locationName = mapItem.name ?? ""
                    address = mapItem.placemark.title ?? ""
                    latitude = mapItem.placemark.coordinate.latitude
                    longitude = mapItem.placemark.coordinate.longitude
                }
            }
            .onAppear(perform: load)
            .onChange(of: pickerItems) { _, newItems in
                guard !newItems.isEmpty else { return }
                Task {
                    for pickerItem in newItems {
                        if let data = try? await pickerItem.loadTransferable(type: Data.self) {
                            pendingImages.append(data)
                        }
                    }
                    pickerItems = []
                }
            }
        }
    }

    // MARK: - 表单分区

    private var typeSection: some View {
        Section {
            Picker("类型", selection: $type) {
                ForEach(ItemType.allCases) { itemType in
                    Label(itemType.label, systemImage: itemType.icon)
                        .tag(itemType)
                }
            }
        }
    }

    private var basicSection: some View {
        Section("基本信息") {
            TextField(titlePlaceholder, text: $title)
            Picker("日期", selection: $dayIndex) {
                ForEach(0..<trip.dayCount, id: \.self) { day in
                    Text("第\(day + 1)天 · \(trip.date(forDay: day).monthDayZH)")
                        .tag(day)
                }
            }
            Toggle("开始时间", isOn: $hasStartTime.animation())
            if hasStartTime {
                DatePicker("开始", selection: $startTime, displayedComponents: .hourAndMinute)
            }
            Toggle("结束时间", isOn: $hasEndTime.animation())
            if hasEndTime {
                DatePicker("结束", selection: $endTime, displayedComponents: .hourAndMinute)
            }
        }
    }

    private var titlePlaceholder: String {
        switch type {
        case .flight: return "标题（如：北京 → 成都）"
        case .train: return "标题（如：G89 北京西 → 成都东）"
        case .hotel: return "酒店名称"
        case .attraction: return "景点名称"
        case .food: return "餐厅/美食名称"
        case .transport: return "交通安排（如：机场大巴）"
        case .other: return "标题"
        }
    }

    private var locationSection: some View {
        Section("地点") {
            Button {
                showLocationSearch = true
            } label: {
                HStack {
                    Image(systemName: "magnifyingglass")
                    Text(locationName.isEmpty ? "搜索并选择地点" : locationName)
                        .foregroundStyle(locationName.isEmpty ? .secondary : .primary)
                    Spacer()
                    if latitude != nil {
                        Image(systemName: "mappin.circle.fill")
                            .foregroundStyle(.green)
                    }
                }
            }
            if !address.isEmpty {
                Text(address)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            if latitude != nil || !locationName.isEmpty {
                Button("清除地点", role: .destructive) {
                    locationName = ""
                    address = ""
                    latitude = nil
                    longitude = nil
                }
                .font(.caption)
            }
        }
    }

    @ViewBuilder
    private var typeSpecificSection: some View {
        if type.isPointToPoint {
            Section(type == .flight ? "航班信息" : (type == .train ? "车次信息" : "班次信息")) {
                TextField(type == .flight ? "航班号（如 CA4102）" : (type == .train ? "车次（如 G89）" : "班次号"), text: $transportNumber)
                    .textInputAutocapitalization(.characters)
                TextField("出发地（如 北京首都T3）", text: $departurePlace)
                TextField("到达地（如 成都天府T1）", text: $arrivalPlace)
            }
        } else if type == .hotel {
            Section("入住信息") {
                Toggle("填写入住/退房日期", isOn: $hasHotelDates.animation())
                if hasHotelDates {
                    DatePicker("入住", selection: $checkInDate, displayedComponents: .date)
                    DatePicker("退房", selection: $checkOutDate, in: checkInDate..., displayedComponents: .date)
                }
            }
        }

        Section("费用") {
            TextField(type == .hotel ? "房费（元）" : (type == .attraction ? "门票（元）" : "费用（元）"), text: $priceText)
                .keyboardType(.decimalPad)
        }
    }

    private var bookingSection: some View {
        Section {
            Picker("预订平台", selection: $platformSelection) {
                Text("未关联").tag("")
                ForEach(BookingPlatform.allCases) { platform in
                    Text(platform.label).tag(platform.rawValue)
                }
            }
            if platformSelection == BookingPlatform.custom.rawValue {
                TextField("平台名称（如 官网、支付宝小程序）", text: $customPlatformName)
            }
            TextField("订单号", text: $orderNumber)
                .textInputAutocapitalization(.characters)
                .autocorrectionDisabled()
            TextField("联系电话（酒店/客服）", text: $phoneNumber)
                .keyboardType(.phonePad)
            TextField("订单链接（从预订App分享里复制）", text: $bookingURLString)
                .keyboardType(.URL)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
        } header: {
            Text("预订信息")
        } footer: {
            Text("保存后卡片上会出现「打开App / 打开链接 / 打电话 / 复制订单号」按钮：一键唤起预订平台改单退订、致电酒店、粘贴订单号查单。")
        }
    }

    private var attachmentSection: some View {
        Section("附件（票据/证件截图）") {
            PhotosPicker(selection: $pickerItems, maxSelectionCount: 5, matching: .images) {
                Label("添加照片", systemImage: "photo.badge.plus")
            }
            let existingAttachments = existing?.attachments ?? []
            if !existingAttachments.isEmpty || !pendingImages.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(existingAttachments) { attachment in
                            attachmentThumbnail(data: attachment.data) {
                                context.delete(attachment)
                            }
                        }
                        ForEach(Array(pendingImages.enumerated()), id: \.offset) { index, data in
                            attachmentThumbnail(data: data) {
                                if index < pendingImages.count {
                                    pendingImages.remove(at: index)
                                }
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }
            }
        }
    }

    private func attachmentThumbnail(data: Data, onDelete: @escaping () -> Void) -> some View {
        ZStack(alignment: .topTrailing) {
            if let uiImage = UIImage(data: data) {
                Image(uiImage: uiImage)
                    .resizable()
                    .scaledToFill()
                    .frame(width: 72, height: 72)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(.quaternary)
                    .frame(width: 72, height: 72)
            }
            Button(action: onDelete) {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.white, .black.opacity(0.55))
            }
            .buttonStyle(.borderless)
            .padding(3)
        }
    }

    private var notesSection: some View {
        Section("备注") {
            TextField("取票口、预约码、注意事项…", text: $notes, axis: .vertical)
                .lineLimit(2...6)
        }
    }

    private var deleteSection: some View {
        Section {
            Button("删除此条目", role: .destructive) {
                if let existing {
                    context.delete(existing)
                }
                dismiss()
            }
        }
    }

    // MARK: - 读写

    private func load() {
        guard !loaded else { return }
        loaded = true
        dayIndex = min(max(0, defaultDay), trip.dayCount - 1)
        guard let item = existing else { return }
        type = item.type
        title = item.title
        dayIndex = item.dayIndex
        if let start = item.startTime {
            hasStartTime = true
            startTime = start
        }
        if let end = item.endTime {
            hasEndTime = true
            endTime = end
        }
        locationName = item.locationName
        address = item.address
        latitude = item.latitude
        longitude = item.longitude
        notes = item.notes
        priceText = item.price > 0 ? String(format: "%.0f", item.price) : ""
        transportNumber = item.transportNumber
        departurePlace = item.departurePlace
        arrivalPlace = item.arrivalPlace
        if let checkIn = item.checkInDate, let checkOut = item.checkOutDate {
            hasHotelDates = true
            checkInDate = checkIn
            checkOutDate = checkOut
        }
        platformSelection = item.platformRaw
        customPlatformName = item.customPlatformName
        orderNumber = item.orderNumber
        phoneNumber = item.phoneNumber
        bookingURLString = item.bookingURLString
    }

    private func save() {
        let item: ItineraryItem
        if let existing {
            item = existing
            if existing.dayIndex != dayIndex {
                item.sortIndex = nextSortIndex(day: dayIndex)
            }
        } else {
            item = ItineraryItem(title: "", type: type, dayIndex: dayIndex, sortIndex: nextSortIndex(day: dayIndex))
            item.trip = trip
            context.insert(item)
        }

        item.type = type
        item.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        item.dayIndex = dayIndex
        item.startTime = hasStartTime ? combine(day: dayIndex, time: startTime) : nil
        item.endTime = hasEndTime ? combine(day: dayIndex, time: endTime) : nil
        item.locationName = locationName
        item.address = address
        item.latitude = latitude
        item.longitude = longitude
        item.notes = notes
        item.price = Double(priceText) ?? 0
        item.transportNumber = transportNumber.trimmingCharacters(in: .whitespaces)
        item.departurePlace = departurePlace
        item.arrivalPlace = arrivalPlace
        item.checkInDate = hasHotelDates ? checkInDate.startOfDay : nil
        item.checkOutDate = hasHotelDates ? checkOutDate.startOfDay : nil
        item.platformRaw = platformSelection
        item.customPlatformName = customPlatformName
        item.orderNumber = orderNumber.trimmingCharacters(in: .whitespaces)
        item.phoneNumber = phoneNumber.trimmingCharacters(in: .whitespaces)
        item.bookingURLString = bookingURLString.trimmingCharacters(in: .whitespaces)

        for data in pendingImages {
            let attachment = Attachment(data: data)
            attachment.item = item
            context.insert(attachment)
        }

        dismiss()
        Task { @MainActor in
            await NotificationService.rescheduleAll(context: context)
        }
    }

    private func nextSortIndex(day: Int) -> Int {
        (trip.items(forDay: day).map(\.sortIndex).max() ?? -1) + 1
    }

    /// 把「时分」合到该天的日期上。
    private func combine(day: Int, time: Date) -> Date {
        let dayDate = trip.date(forDay: day)
        let comps = Calendar.current.dateComponents([.hour, .minute], from: time)
        return Calendar.current.date(
            bySettingHour: comps.hour ?? 9,
            minute: comps.minute ?? 0,
            second: 0,
            of: dayDate
        ) ?? dayDate
    }
}
