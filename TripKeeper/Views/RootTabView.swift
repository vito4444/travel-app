import SwiftUI

struct RootTabView: View {
    var body: some View {
        TabView {
            TripListView()
                .tabItem { Label("行程", systemImage: "suitcase.fill") }
            StatsView()
                .tabItem { Label("足迹", systemImage: "map.fill") }
            SettingsView()
                .tabItem { Label("设置", systemImage: "gearshape.fill") }
        }
    }
}

#Preview {
    RootTabView()
        .modelContainer(for: [Trip.self, ItineraryItem.self, Attachment.self, Expense.self, ChecklistItem.self], inMemory: true)
}
