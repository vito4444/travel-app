import SwiftUI
import SwiftData

@main
struct TripKeeperApp: App {
    let container: ModelContainer

    init() {
        do {
            container = try ModelContainer(for:
                Trip.self,
                ItineraryItem.self,
                Attachment.self,
                Expense.self,
                ChecklistItem.self
            )
        } catch {
            fatalError("ModelContainer 创建失败: \(error)")
        }
        DemoData.seedIfNeeded(context: container.mainContext)
    }

    var body: some Scene {
        WindowGroup {
            RootTabView()
        }
        .modelContainer(container)
    }
}
