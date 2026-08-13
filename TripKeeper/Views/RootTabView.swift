import SwiftUI

struct RootTabView: View {
    @Environment(\.modelContext) private var context

    var body: some View {
        TabView {
            TripListView()
                .tabItem { Label("行程", systemImage: "suitcase.fill") }
            StatsView()
                .tabItem { Label("足迹", systemImage: "map.fill") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
        }
        .task {
            await NotificationService.rescheduleAll(context: context)
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: [Trip.self, ItineraryItem.self, Attachment.self, Expense.self, ChecklistItem.self], inMemory: true)
}
