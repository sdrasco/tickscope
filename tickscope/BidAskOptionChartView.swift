import SwiftUI
import Charts

struct BidAskOptionChartView: View {
    @ObservedObject var webSocketManager: WebSocketManager

    var body: some View {
        VStack {
            Text("Option quote Bid-Ask ($)")
                .font(.headline)
                .padding()

            Chart {
                ForEach(webSocketManager.bidAskOptionPrices, id: \.timestamp) { quote in
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
            .chartYScale(domain: bidAskOptionRange())
        }
    }

    private func bidAskOptionRange() -> ClosedRange<Double> {
        guard let minPrice = webSocketManager.bidAskOptionPrices.map({ $0.bidPrice }).min(),
              let maxPrice = webSocketManager.bidAskOptionPrices.map({ $0.askPrice }).max() else {
            return 5...20
        }
        let padding = (maxPrice - minPrice) * 0.1
        return (minPrice - padding)...(maxPrice + padding)
    }
}
