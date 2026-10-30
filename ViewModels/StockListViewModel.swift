import Combine
import Foundation

// MARK:  -  Stock List View Model  -  
@MainActor
final class StockListViewModel: ObservableObject {
    @Published private(set) var stocks: [Stock] = []
    @Published private(set) var loadError: String?
    @Published private(set) var status: FeedStatus = .stopped
    @Published var sortOption: StockSort = .alphabetical
    private let feed: any StockFeedProviding

    init(catalog: StockCatalog = StockCatalog(), feed: (any StockFeedProviding)? = nil) {
        self.feed = feed ?? StockFeedClient()
        do {
            stocks = try catalog.loadStocks()
        } catch {
            loadError = error.localizedDescription
        }

        self.feed.onUpdate = { [weak self] symbol, price, change in
            self?.applyUpdate(symbol: symbol, price: price, change: change)
        }
        self.feed.onStatus = { [weak self] in self?.status = $0 }
    }

    var symbols: [String] { stocks.map(\.symbol) }
    var displayedStocks: [Stock] { sorted(by: sortOption) }
    func stock(for symbol: String) -> Stock? { stocks.first { $0.symbol == symbol } }

    func sorted(by sort: StockSort) -> [Stock] {
        switch sort {
        case .alphabetical: stocks.sorted { $0.symbol < $1.symbol }
        case .price: stocks.sorted { $0.price > $1.price }
        case .change: stocks.sorted { abs($0.change) > abs($1.change) }
        }
    }

    func toggleFeed() {
        if status == .connecting || status == .connected { feed.stop() }
        else { feed.start(stocks: stocks) }
    }

    func applyUpdate(symbol: String, price: Double, change: Double) {
        guard let index = stocks.firstIndex(where: { $0.symbol == symbol }) else { return }
        var updatedStock = stocks[index]
        updatedStock.price = price
        updatedStock.change = change
        stocks[index] = updatedStock
    }
}
