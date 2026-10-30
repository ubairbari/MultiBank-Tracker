import XCTest
@testable import StockTracker

@MainActor
final class StockFeedClientTests: XCTestCase {
    func testEmptyWatchlistDoesNotCreateConnection() {
        let factory = MockSocketFactory()
        let client = StockFeedClient(socketFactory: factory)

        client.start(stocks: [])

        XCTAssertEqual(factory.connectionCount, 0)
    }

    func testStartEmitsGeneratedPriceUpdateAndConnects() async {
        let factory = MockSocketFactory()
        let client = StockFeedClient(socketFactory: factory, tickInterval: .milliseconds(10))
        let updateReceived = expectation(description: "echoed price update received")
        let stock = makeStock()
        var received: (String, Double, Double)?
        var statuses: [FeedStatus] = []
        client.onUpdate = { symbol, price, change in
            received = (symbol, price, change)
            updateReceived.fulfill()
        }
        client.onStatus = { statuses.append($0) }

        client.start(stocks: [stock])
        await fulfillment(of: [updateReceived], timeout: 2)

        XCTAssertEqual(factory.connectionCount, 1)
        XCTAssertEqual(statuses.first, .connecting)
        XCTAssertEqual(statuses.last, .connected)
        XCTAssertEqual(received?.0, stock.symbol)
        XCTAssertNotEqual(received?.1, stock.price)
        XCTAssertEqual(received?.1 ?? 0, stock.price + (received?.2 ?? 0), accuracy: 0.000_001)
        client.stop()
    }

    func testRepeatedStartDoesNotOpenAnotherSocket() {
        let factory = MockSocketFactory()
        let client = StockFeedClient(socketFactory: factory)
        let stock = makeStock()

        client.start(stocks: [stock])
        client.start(stocks: [stock])

        XCTAssertEqual(factory.connectionCount, 1)
        client.stop()
    }

    func testMalformedMessagesAreIgnoredAndReceiveFailureDisconnects() async {
        let factory = MockSocketFactory()
        let client = StockFeedClient(socketFactory: factory, tickInterval: .seconds(30))
        let stock = makeStock()
        let validUpdate = expectation(description: "valid message delivered")
        let disconnected = expectation(description: "receive failure disconnects feed")
        var updates = 0
        client.onUpdate = { _, _, _ in
            updates += 1
            validUpdate.fulfill()
        }
        client.onStatus = { if $0 == .disconnected { disconnected.fulfill() } }

        client.start(stocks: [stock])
        let connection = try! XCTUnwrap(factory.connection)
        connection.yield("not json")
        connection.yield("{\"symbol\":\"AAPL\",\"price\":200,\"change\":2}")
        await fulfillment(of: [validUpdate], timeout: 2)
        connection.failReceive()
        await fulfillment(of: [disconnected], timeout: 2)

        XCTAssertEqual(updates, 1)
    }

    func testStopCancelsSocketAndReportsStopped() {
        let factory = MockSocketFactory()
        let client = StockFeedClient(socketFactory: factory)
        var statuses: [FeedStatus] = []
        client.onStatus = { statuses.append($0) }

        client.start(stocks: [makeStock()])
        client.stop()

        XCTAssertTrue(factory.connection?.isCancelled == true)
        XCTAssertEqual(statuses.last, .stopped)
    }

    func testSendFailureDisconnectsFeed() async {
        let factory = MockSocketFactory()
        factory.failSends = true
        let client = StockFeedClient(socketFactory: factory, tickInterval: .milliseconds(1))
        let disconnected = expectation(description: "send failure disconnects feed")
        client.onStatus = { if $0 == .disconnected { disconnected.fulfill() } }

        client.start(stocks: [makeStock()])
        await fulfillment(of: [disconnected], timeout: 2)

        XCTAssertTrue(factory.connection?.isCancelled == true)
    }

    private func makeStock() -> Stock {
        Stock(symbol: "AAPL", name: "Apple Inc.", description: "Technology", price: 200, change: 0)
    }
}

@MainActor
private final class MockSocketFactory: StockSocketFactory {
    private(set) var connectionCount = 0
    private(set) var connection: MockSocketConnection?
    var failSends = false

    func makeConnection(to url: URL) -> any StockSocketConnection {
        connectionCount += 1
        let connection = MockSocketConnection(failSends: failSends)
        self.connection = connection
        return connection
    }
}

@MainActor
private final class MockSocketConnection: StockSocketConnection {
    private var pendingReceivers: [CheckedContinuation<String, Error>] = []
    private var queuedResults: [Result<String, Error>] = []
    private(set) var isCancelled = false

    private let failSends: Bool

    init(failSends: Bool = false) {
        self.failSends = failSends
    }

    func resume() {}

    func send(_ text: String) async throws {
        if failSends { throw URLError(.networkConnectionLost) }
        yield(text) // The production endpoint echoes each generated message.
    }

    func receive() async throws -> String {
        if !queuedResults.isEmpty { return try queuedResults.removeFirst().get() }
        return try await withCheckedThrowingContinuation { pendingReceivers.append($0) }
    }

    func yield(_ text: String) {
        enqueue(.success(text))
    }

    func failReceive() {
        enqueue(.failure(URLError(.networkConnectionLost)))
    }

    func cancel() {
        isCancelled = true
        let receivers = pendingReceivers
        pendingReceivers.removeAll()
        receivers.forEach { $0.resume(throwing: CancellationError()) }
    }

    private func enqueue(_ result: Result<String, Error>) {
        guard !isCancelled else { return }
        if pendingReceivers.isEmpty {
            queuedResults.append(result)
        } else {
            pendingReceivers.removeFirst().resume(with: result)
        }
    }
}
