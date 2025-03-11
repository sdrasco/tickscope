import SwiftUI
import Charts

struct BidAskStockChartView: View {
    @ObservedObject var webSocketManager: WebSocketManager

    var body: some View {
        VStack {
            Text("Stock Bid-Ask Prices")
                .font(.headline)
                .padding()

            Chart {
                ForEach(webSocketManager.bidAskStockPrices, id: \.timestamp) { quote in
                    PointMark( // ✅ Marker for Bids
                        x: .value("Time", quote.timestamp),
                        y: .value("Bid", quote.bidPrice)
                    )
                    .foregroundStyle(.red)

                    PointMark( // ✅ Marker for Asks
                        x: .value("Time", quote.timestamp),
                        y: .value("Ask", quote.askPrice)
                    )
                    .foregroundStyle(.green)
                }
            }
            .chartYScale(domain: bidAskStockRange())
        }
    }

    private func bidAskStockRange() -> ClosedRange<Double> {
        guard let minPrice = webSocketManager.bidAskStockPrices.map({ $0.bidPrice }).min(),
              let maxPrice = webSocketManager.bidAskStockPrices.map({ $0.askPrice }).max() else {
            return 250...260
        }
        let padding = (maxPrice - minPrice) * 0.1
        return (minPrice - padding)...(maxPrice + padding)
    }
}
