//
//  OptionPriceChartView.swift
//  TickscopeSwift
//
//  Created by sdrasco on 10/03/2025.
//

import SwiftUI
import Charts

struct OptionPriceChartView: View {
    @ObservedObject var webSocketManager: WebSocketManager

    var body: some View {
        VStack {
            Text("Traded Option Premium ($)")
                .font(.headline)
                .padding()

            Chart {
                ForEach(webSocketManager.optionTradePrices, id: \.timestamp) { trade in
                    PointMark(
                        x: .value("Time", trade.timestamp),
                        y: .value("Price", trade.price)
                    )
                    .foregroundStyle(.purple)
                }
            }
            .chartYScale(domain: optionPriceRange())
        }
    }

    private func optionPriceRange() -> ClosedRange<Double> {
        let prices = webSocketManager.optionTradePrices.map { $0.price }
        guard let minPrice = prices.min(),
              let maxPrice = prices.max() else {
            return 0...1 // default if no data is present
        }

        if minPrice == maxPrice {
            // When there's only one data point, add a sensible ±10% padding
            let padding = max(minPrice * 0.1, 0.1) // Ensure padding isn't zero
            return (minPrice - padding)...(maxPrice + padding)
        } else {
            // When multiple points exist, use actual min/max with padding
            let padding = (maxPrice - minPrice) * 0.1
            return (minPrice - padding)...(maxPrice + padding)
        }
    }
}
