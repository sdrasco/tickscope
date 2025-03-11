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
            Text("Traded Option Premium")
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
        guard let minPrice = webSocketManager.optionTradePrices.map({ $0.price }).min(),
              let maxPrice = webSocketManager.optionTradePrices.map({ $0.price }).max() else {
            return 5...20
        }
        let padding = (maxPrice - minPrice) * 0.1
        return (minPrice - padding)...(maxPrice + padding)
    }
}
