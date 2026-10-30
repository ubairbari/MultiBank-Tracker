import Foundation

@MainActor
protocol StockFeedProviding: AnyObject {
    var onUpdate: ((String, Double, Double) -> Void)? { get set }
    var onStatus: ((FeedStatus) -> Void)? { get set }
    func start(stocks: [Stock])
    func stop()
}

@MainActor
protocol StockSocketConnection: AnyObject {
    func resume()
    func send(_ text: String) async throws
    func receive() async throws -> String
    func cancel()
}

@MainActor
protocol StockSocketFactory {
    func makeConnection(to url: URL) -> any StockSocketConnection
}

@MainActor
private struct URLSessionStockSocketFactory: StockSocketFactory {
    func makeConnection(to url: URL) -> any StockSocketConnection {
        URLSessionStockSocket(url: url)
    }
}

@MainActor
private final class URLSessionStockSocket: StockSocketConnection {
    private let task: URLSessionWebSocketTask

    init(url: URL) {
        task = URLSession.shared.webSocketTask(with: url)
    }

    func resume() { task.resume() }

    func send(_ text: String) async throws {
        try await task.send(.string(text))
    }

    func receive() async throws -> String {
        let message = try await task.receive()
        return switch message {
        case .string(let text): text
        case .data(let data): String(decoding: data, as: UTF8.self)
        @unknown default: throw StockFeedError.unsupportedMessage
        }
    }

    func cancel() {
        task.cancel(with: .normalClosure, reason: nil)
    }
}

private enum StockFeedError: Error {
    case unsupportedMessage
}

// MARK:  -  Feed Client  -  
@MainActor
final class StockFeedClient: StockFeedProviding {
    private let endpoint = URL(string: "wss://ws.postman-echo.com/raw")!
    private let socketFactory: any StockSocketFactory
    private let tickInterval: Duration
    private var socket: (any StockSocketConnection)?
    private var receiveTask: Task<Void, Never>?
    private var generatorTask: Task<Void, Never>?
    private var lastPrices: [String: Double] = [:]
    var onUpdate: ((String, Double, Double) -> Void)?
    var onStatus: ((FeedStatus) -> Void)?

    init(socketFactory: (any StockSocketFactory)? = nil, tickInterval: Duration = .seconds(1)) {
        self.socketFactory = socketFactory ?? URLSessionStockSocketFactory()
        self.tickInterval = tickInterval
    }

    func start(stocks: [Stock]) {
        guard socket == nil, !stocks.isEmpty else { return }
        onStatus?(.connecting)
        lastPrices = Dictionary(uniqueKeysWithValues: stocks.map { ($0.symbol, $0.price) })
        let connection = socketFactory.makeConnection(to: endpoint)
        socket = connection
        connection.resume()
        receiveTask = Task { [weak self] in await self?.receiveLoop() }
        generatorTask = Task { [weak self] in await self?.generateLoop(stocks: stocks) }
    }

    func stop() {
        tearDownConnection()
        onStatus?(.stopped)
    }

    private func tearDownConnection() {
        generatorTask?.cancel()
        receiveTask?.cancel()
        generatorTask = nil
        receiveTask = nil
        socket?.cancel()
        socket = nil
        lastPrices.removeAll()
    }

    private func disconnect() {
        tearDownConnection()
        onStatus?(.disconnected)
    }

    private func generateLoop(stocks: [Stock]) async {
        guard !stocks.isEmpty else { return }
        while !Task.isCancelled, let socket {
            do {
                try await Task.sleep(for: tickInterval)
                guard !Task.isCancelled else { return }
                let stock = stocks.randomElement() ?? stocks[0]
                let previousPrice = lastPrices[stock.symbol] ?? stock.price
                let maximumMove = max(previousPrice * 0.005, 0.01)
                let change = Double.random(in: -maximumMove...maximumMove)
                let price = max(previousPrice + change, 0.01)
                lastPrices[stock.symbol] = price
                let message = PriceMessage(symbol: stock.symbol, price: price, change: change)
                let data = try JSONEncoder().encode(message)
                try await socket.send(String(decoding: data, as: UTF8.self))
            } catch is CancellationError {
                return
            } catch {
                disconnect()
                return
            }
        }
    }

    private func receiveLoop() async {
        while !Task.isCancelled, let socket {
            do {
                let text = try await socket.receive()
                guard let data = text.data(using: .utf8),
                      let update = try? JSONDecoder().decode(PriceMessage.self, from: data) else { continue }
                onStatus?(.connected)
                onUpdate?(update.symbol, update.price, update.change)
            } catch {
                guard !Task.isCancelled else { return }
                disconnect()
                return
            }
        }
    }
}

private struct PriceMessage: Codable {
    let symbol: String
    let price: Double
    let change: Double
}
