import Foundation

// MARK:  -  Models  -  
struct Stock: Identifiable, Hashable, Codable {
    let symbol: String
    let name: String
    let description: String
    var price: Double
    var change: Double

    var id: String { symbol }
}

enum StockSort: String, CaseIterable, Identifiable {
    case alphabetical = "A–Z"
    case price = "Price"
    case change = "Price Change"
    var id: String { rawValue }
}

enum FeedStatus: Equatable {
    case stopped, connecting, connected, disconnected
    var label: String {
        switch self {
        case .stopped: "Feed stopped"
        case .connecting: "Connecting…"
        case .connected: "Connected"
        case .disconnected: "Disconnected"
        }
    }
}
