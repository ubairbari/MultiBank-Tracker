import SwiftUI

// MARK:  -  Detail Screen  -  
struct StockDetailView: View {
    @EnvironmentObject private var viewModel: StockListViewModel
    let symbol: String

    var body: some View {
        Group {
            if let stock = viewModel.stock(for: symbol) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 22) {
                        VStack(alignment: .leading, spacing: 8) {
                            Text(stock.symbol).font(.largeTitle.bold())
                            Text(stock.name).font(.title3).foregroundStyle(.secondary)
                        }
                        VStack(alignment: .leading, spacing: 10) {
                            Text(stock.price, format: .currency(code: "USD")).font(.system(size: 42, weight: .bold, design: .rounded)).contentTransition(.numericText())
                            ChangeLabel(change: stock.change)
                        }
                        Divider()
                        VStack(alignment: .leading, spacing: 8) {
                            Text("About").font(.headline)
                            Text(stock.description).foregroundStyle(.secondary)
                        }
                    }
                    .padding(20)
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                ContentUnavailableView("Stock not found", systemImage: "chart.line.downtrend.xyaxis")
            }
        }
        .navigationTitle(symbol)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar(.visible, for: .navigationBar)
    }

}
