//
//  OptionPriceChartView.swift
//  TickscopeSwift
//
//  Created by sdrasco on 10/03/2025.
//  IBKR‑adapted on 09/05/2025
//

import SwiftUI
import Charts

struct OptionPriceChartView: View {
    /// IBKR streaming manager (replaces Polygon WebSocketManager)
    @ObservedObject var webSocketManager: IBKRWebSocketManager
    /// The concrete option’s conid (used to filter trade ticks)

    let optionConid: Int

    var body: some View {
        VStack {
            Text("Traded Option Premium ($)")
                .font(.headline)
                .padding()

            Chart(optionTrades, id: \.id) { trade in
                PointMark(
                    x: .value("Time", trade.timestamp),
                    y: .value("Price", trade.price)
                )
                .opacity(0.8)
                .symbol(.circle)
            }
            .chartYScale(domain: priceRange())
        }
    }

    // MARK: – Helpers -------------------------------------------------------

    /// Trade ticks that belong to **this** option contract only.
    private var optionTrades: [TradeDatum] {
        webSocketManager.trades.filter { $0.conid == optionConid }
    }

    /// Dynamic y‑axis that adds ±10 % padding around the live window.
    private func priceRange() -> ClosedRange<Double> {
        let prices = optionTrades.map(\.price)
        guard
            let minPrice = prices.min(),
            let maxPrice = prices.max(),
            maxPrice > minPrice
        else { return 0...1 }     // fallback when no data yet

        let padding = (maxPrice - minPrice) * 0.1
        return (minPrice - padding)...(maxPrice + padding)
    }
}
