import SwiftUI

// MARK:  -  List Screen  -  
struct StockListView: View {
    @EnvironmentObject private var viewModel: StockListViewModel

    var body: some View {
        NavigationStack {
            ZStack(alignment: .top) {
                Color(uiColor: .systemGroupedBackground)
                    .ignoresSafeArea()

                if let error = viewModel.loadError {
                    ContentUnavailableView(
                        "Stocks Unavailable",
                        systemImage: "exclamationmark.triangle",
                        description: Text(error)
                    )
                } else {
                    stockList
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .containerRelativeFrame([.horizontal, .vertical])
            .navigationDestination(for: String.self) { symbol in
                StockDetailView(symbol: symbol)
            }
            .toolbar(.hidden, for: .navigationBar)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(uiColor: .systemGroupedBackground).ignoresSafeArea())
    }

    private var stockList: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 20)
                .padding(.top, 14)
                .padding(.bottom, 18)
                .background(Color(uiColor: .systemGroupedBackground))

            ScrollView {
                VStack(alignment: .leading, spacing: 22) {
                    watchlistHeading

                    LazyVStack(spacing: 10) {
                        ForEach(viewModel.displayedStocks) { stock in
                            NavigationLink(value: stock.symbol) {
                                StockRowView(stock: stock)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 28)
                .frame(maxWidth: .infinity)
            }
            .scrollIndicators(.hidden)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top, spacing: 12) {
                VStack(alignment: .leading, spacing: 5) {
                    Text("Markets")
                        .font(.system(.largeTitle, design: .rounded, weight: .bold))
                        .tracking(-0.4)
                    Text("Sample market data · simulated prices")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 4)

                FeedStatusBadge(status: viewModel.status)
                    .padding(.top, 5)
            }

            Button {
                withAnimation { viewModel.toggleFeed() }
            } label: {
                Label(
                    isFeedRunning ? "Stop Price Feed" : "Start Price Feed",
                    systemImage: isFeedRunning ? "stop.fill" : "play.fill"
                )
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.borderedProminent)
            .tint(isFeedRunning ? .red : .accentColor)

            sortControl
        }
        .accessibilityElement(children: .contain)
    }

    private var isFeedRunning: Bool {
        viewModel.status == .connecting || viewModel.status == .connected
    }

    private var sortControl: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("SORT BY")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(.secondary)

            Picker("Sort stocks", selection: $viewModel.sortOption) {
                ForEach(StockSort.allCases) { option in
                    Text(option.rawValue).tag(option)
                }
            }
            .pickerStyle(.segmented)
        }
    }

    private var watchlistHeading: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("WATCHLIST")
                .font(.caption.weight(.semibold))
                .tracking(0.8)
                .foregroundStyle(.secondary)
            Spacer()
            Text("\(viewModel.stocks.count) stocks")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.bottom, -12)
    }
}

// MARK:  -  Feed Status Badge  -  
private struct FeedStatusBadge: View {
    let status: FeedStatus

    private var tint: Color {
        switch status {
        case .connected: .green
        case .connecting: .orange
        case .disconnected: .red
        case .stopped: .secondary
        }
    }

    var body: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(tint)
                .frame(width: 7, height: 7)
            Text(status.label)
                .font(.caption.weight(.medium))
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .foregroundStyle(tint)
        .padding(.horizontal, 10)
        .padding(.vertical, 7)
        .background(tint.opacity(0.10), in: Capsule())
        .accessibilityElement(children: .combine)
    }
}
