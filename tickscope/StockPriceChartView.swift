//
//  StockPriceChartView.swift
//  TickscopeSwift
//
//  Created by sdrasco on 10/03/2025.
//  IBKR-adapted on 09/05/2025
//

import SwiftUI
import Charts

struct StockPriceChartView: View {
    /// IBKR streaming manager (replaces Polygon WebSocketManager)
    @ObservedObject var webSocketManager: IBKRWebSocketManager

    /// Contract identifier for the underlying stock we’re charting
    let stockConid: Int

    /// Only the trade ticks that belong to the selected stock
    private var stockTrades: [TradeDatum] {
        webSocketManager.trades.filter { $0.conid == stockConid }
    }

    var body: some View {
        VStack {
            Text("Traded Stock Price ($)")
                .font(.headline)
                .padding()

            Chart(stockTrades, id: \.id) { trade in
                PointMark(
                    x: .value("Time", trade.timestamp),
                    y: .value("Price", trade.price)
                )
                .opacity(0.8)
            }
            .chartYScale(domain: priceRange())
        }
    }

    /// Compute a dynamic y-axis with 10 % padding.
    private func priceRange() -> ClosedRange<Double> {
        let prices = stockTrades.map(\.price)

        guard
            let minPrice = prices.min(),
            let maxPrice = prices.max(),
            maxPrice > minPrice
        else {
            return 0...1      // Fallback if no data yet
        }

        let padding = (maxPrice - minPrice) * 0.1
        return (minPrice - padding)...(maxPrice + padding)
    }
}
