import SwiftUI
import Charts

struct StockPriceChartView: View {
    @ObservedObject var webSocketManager: WebSocketManager

    var body: some View {
        VStack {
            Text("Traded Stock Price ($)")
                .font(.headline)
                .padding()

            Chart {
                ForEach(webSocketManager.tradePrices, id: \.timestamp) { trade in
                    PointMark(
                        x: .value("Time", trade.timestamp),
                        y: .value("Price", trade.price)
                    )
                    .foregroundStyle(.blue)
                }
            }
            .chartYScale(domain: priceRange())
        }
    }

    private func priceRange() -> ClosedRange<Double> {
        guard let minPrice = webSocketManager.tradePrices.map({ $0.price }).min(),
              let maxPrice = webSocketManager.tradePrices.map({ $0.price }).max() else {
            return 250...260  // Default range if no data
        }

        let padding = (maxPrice - minPrice) * 0.1  // Add 10% padding
        return (minPrice - padding)...(maxPrice + padding)
    }
}
