import SwiftUI
import SwiftData

@main
struct TripKeeperApp: App {
    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(for: [
            Trip.self,
            ItineraryItem.self,
            Attachment.self,
            Expense.self,
            ChecklistItem.self
        ])
    }
}
