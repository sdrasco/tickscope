//
//  BidAskStockChartView.swift
//  TickscopeSwift
//
//  Created by sdrasco on 10/03/2025.
//  IBKR-adapted on 09/05/2025
//

import SwiftUI
import Charts

struct BidAskStockChartView: View {
    /// IBKR streaming manager (replaces Polygon WebSocketManager)
    @ObservedObject var webSocketManager: IBKRWebSocketManager
    let stockConid: Int          // concrete stock contract to plot

    var body: some View {
        VStack {
            Text("Stock Quote Bid-Ask ($)")
                .font(.headline)
                .padding()

            Chart(filteredQuotes, id: \.id) { quote in
                // Bid marker
                if let bid = quote.bid {
                    PointMark(
                        x: .value("Time", quote.timestamp),
                        y: .value("Bid", bid)
                    )
                    .symbol(.circle)      // built-in symbol shape
                    .opacity(0.8)
                }
                // Ask marker
                if let ask = quote.ask {
                    PointMark(
                        x: .value("Time", quote.timestamp),
                        y: .value("Ask", ask)
                    )
                    .symbol(.square)      // built-in symbol shape
                    .opacity(0.8)
                }
            }
            .chartYScale(domain: priceRange())
        }
    }

    // MARK: – Helpers -------------------------------------------------------

    /// Quotes for *this* stock that carry a bid or ask value.
    private var filteredQuotes: [QuoteDatum] {
        webSocketManager.quotes
            .filter { $0.conid == stockConid && ($0.bid != nil || $0.ask != nil) }
    }

    private func priceRange() -> ClosedRange<Double> {
        let bids = filteredQuotes.compactMap(\.bid)
        let asks = filteredQuotes.compactMap(\.ask)
        guard
            let minPrice = (bids + asks).min(),
            let maxPrice = (bids + asks).max(),
            maxPrice > minPrice
        else { return 0...1 }

        let padding = (maxPrice - minPrice) * 0.1
        return (minPrice - padding)...(maxPrice + padding)
    }
}
