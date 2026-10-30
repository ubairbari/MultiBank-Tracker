import SwiftUI

// MARK:  -  App  -  
@main
struct StockTrackerApp: App {
    @StateObject private var viewModel = StockListViewModel()

    var body: some Scene {
        WindowGroup {
            StockListView()
                .environmentObject(viewModel)
        }
    }
}
