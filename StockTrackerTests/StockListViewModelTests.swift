import XCTest
@testable import StockTracker

@MainActor
final class StockListViewModelTests: XCTestCase {
    func testBundledCatalogContainsTwentyFiveSymbols() throws {
        let stocks = try StockCatalog().loadStocks()
        XCTAssertEqual(stocks.count, 25)
        XCTAssertEqual(Set(stocks.map(\.symbol)).count, 25)
    }

    func testAlphabeticalSortOrdersSymbolsAscendingAndIsDefault() {
        let store = StockListViewModel()

        XCTAssertEqual(store.sortOption, .alphabetical)
        XCTAssertEqual(store.sorted(by: .alphabetical).map(\.symbol), store.symbols.sorted())
    }

    func testPriceSortOrdersHighestFirst() {
        let store = StockListViewModel()
        let sorted = store.sorted(by: .price)
        XCTAssertEqual(sorted, sorted.sorted { $0.price > $1.price })
    }

    func testChangeSortUsesAbsoluteChangeHighestFirst() {
        let store = StockListViewModel()
        let sorted = store.sorted(by: .change)
        XCTAssertEqual(sorted.map { abs($0.change) }, sorted.map { abs($0.change) }.sorted(by: >))
    }

    func testUpdateChangesOnlyMatchingSymbol() {
        let store = StockListViewModel()
        let previousAAPL = store.stock(for: "AAPL")
        let previousMSFT = store.stock(for: "MSFT")

        store.applyUpdate(symbol: "AAPL", price: 200, change: -3.5)

        XCTAssertEqual(store.stock(for: "AAPL")?.price, 200)
        XCTAssertEqual(store.stock(for: "AAPL")?.change, -3.5)
        XCTAssertEqual(store.stock(for: "MSFT"), previousMSFT)
        XCTAssertNotEqual(store.stock(for: "AAPL"), previousAAPL)
    }

    func testUnknownSymbolUpdateIsIgnored() {
        let store = StockListViewModel()
        let before = store.stocks

        store.applyUpdate(symbol: "UNKNOWN", price: 1, change: 0)

        XCTAssertEqual(store.stocks, before)
    }

    func testStartingFeedSubscribesToWholeWatchlist() {
        let feed = MockStockFeed()
        let store = StockListViewModel(feed: feed)

        store.toggleFeed()

        XCTAssertEqual(feed.startedStocks.map(\.symbol), store.symbols)
        XCTAssertEqual(store.status, .connecting)
    }

    func testFeedUpdatesSharedStockStore() {
        let feed = MockStockFeed()
        let store = StockListViewModel(feed: feed)

        feed.onUpdate?("AAPL", 201, 1)

        XCTAssertEqual(store.stock(for: "AAPL")?.price, 201)
        XCTAssertEqual(store.stock(for: "AAPL")?.change, 1)
    }

    func testTogglingConnectedFeedStopsIt() {
        let feed = MockStockFeed()
        let store = StockListViewModel(feed: feed)
        store.toggleFeed()
        feed.onStatus?(.connected)

        store.toggleFeed()

        XCTAssertEqual(feed.stopCallCount, 1)
        XCTAssertEqual(store.status, .stopped)
    }

    func testTogglingDisconnectedFeedAttemptsToRestart() {
        let feed = MockStockFeed()
        let store = StockListViewModel(feed: feed)
        feed.onStatus?(.disconnected)

        store.toggleFeed()

        XCTAssertEqual(feed.startedStocks.map(\.symbol), store.symbols)
        XCTAssertEqual(store.status, .connecting)
    }

    func testDisplayedStocksReflectPriceChangesWithoutLosingAlphabeticalDefault() {
        let store = StockListViewModel()
        let expectedAlphabeticalOrder = store.symbols.sorted()

        store.applyUpdate(symbol: expectedAlphabeticalOrder[0], price: 0.01, change: -1)

        XCTAssertEqual(store.displayedStocks.map(\.symbol), expectedAlphabeticalOrder)
        store.applyUpdate(symbol: "NVDA", price: 5_000, change: 10)
        store.sortOption = .price
        XCTAssertEqual(store.displayedStocks.first?.symbol, "NVDA")
    }
}

@MainActor
private final class MockStockFeed: StockFeedProviding {
    var onUpdate: ((String, Double, Double) -> Void)?
    var onStatus: ((FeedStatus) -> Void)?
    private(set) var startedStocks: [Stock] = []
    private(set) var stopCallCount = 0

    func start(stocks: [Stock]) {
        startedStocks = stocks
        onStatus?(.connecting)
    }

    func stop() {
        stopCallCount += 1
        onStatus?(.stopped)
    }
}
