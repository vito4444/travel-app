import SwiftUI
import SwiftData

struct TripListView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Trip.startDate, order: .reverse) private var trips: [Trip]

    @State private var showingCreator = false
    @State private var tripToDelete: Trip?
    @State private var showDeleteConfirm = false
    /// CI 截图用：`-openFirstTrip` 启动参数自动进入第一个行程。
    @State private var autoOpenTrip: Trip?
    @State private var autoOpened = false

    var body: some View {
        NavigationStack {
            Group {
                if trips.isEmpty {
                    emptyState
                } else {
                    tripList
                }
            }
            .navigationTitle("我的行程")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingCreator = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingCreator) {
                TripEditorView(trip: nil)
            }
            .navigationDestination(item: $autoOpenTrip) { trip in
                TripDetailView(trip: trip)
            }
            .onAppear {
                if !autoOpened,
                   ProcessInfo.processInfo.arguments.contains("-openFirstTrip"),
                   let first = trips.first {
                    autoOpened = true
                    autoOpenTrip = first
                }
            }
            .confirmationDialog(
                "删除行程",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible,
                presenting: tripToDelete
            ) { trip in
                Button("删除「\(trip.name)」", role: .destructive) {
                    context.delete(trip)
                }
                Button("取消", role: .cancel) {}
            } message: { _ in
                Text("行程下的所有条目、清单与账目将一并删除，且不可恢复。")
            }
        }
    }

    private var tripList: some View {
        List {
            ForEach(trips) { trip in
                NavigationLink {
                    TripDetailView(trip: trip)
                } label: {
                    TripCardView(trip: trip)
                }
                .listRowSeparator(.hidden)
                .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    Button {
                        tripToDelete = trip
                        showDeleteConfirm = true
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                    .tint(.red)
                }
            }
        }
        .listStyle(.plain)
    }

    private var emptyState: some View {
        ContentUnavailableView {
            Label("还没有行程", systemImage: "suitcase")
        } description: {
            Text("点右上角 + 创建第一段旅程")
        } actions: {
            Button("新建行程") { showingCreator = true }
                .buttonStyle(.borderedProminent)
        }
    }
}

struct TripCardView: View {
    let trip: Trip

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(trip.name)
                    .font(.title3.bold())
                    .foregroundStyle(.white)
                    .lineLimit(1)
                Spacer()
                Text(trip.statusText)
                    .font(.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(.white.opacity(0.22), in: Capsule())
                    .foregroundStyle(.white)
            }
            HStack(spacing: 6) {
                Image(systemName: "mappin.circle.fill")
                Text(trip.destination.isEmpty ? "未设置目的地" : trip.destination)
            }
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.92))

            HStack {
                Text("\(trip.startDate.monthDayZH) - \(trip.endDate.monthDayZH) · \(trip.dayCount)天")
                Spacer()
                Text("\(trip.items.count) 个安排")
            }
            .font(.caption)
            .foregroundStyle(.white.opacity(0.85))
        }
        .padding(16)
        .background(
            LinearGradient(
                colors: [Color(hex: trip.colorHex), Color(hex: trip.colorHex).opacity(0.72)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            ),
            in: RoundedRectangle(cornerRadius: 16, style: .continuous)
        )
    }
}
