//
//  VolumeStockChartView.swift
//  TickscopeSwift
//
//  Created by sdrasco on 10/03/2025.
//


import SwiftUI
import Charts

struct VolumeStockChartView: View {
    @ObservedObject var webSocketManager: WebSocketManager

    var body: some View {
        VStack {
            Text("Stock Trade Volume (shares)")
                .font(.headline)
                .padding()

            Chart {
                ForEach(webSocketManager.stockVolumes, id: \.id) { volume in
                    BarMark(
                        x: .value("Time", volume.timestamp),
                        y: .value("Volume", volume.volume)
                    )
                    .foregroundStyle(.blue)
                }
            }
            .chartXAxis {
                AxisMarks(values: .stride(by: .minute)) { value in
                    AxisGridLine()
                    AxisValueLabel(format: .dateTime.hour().minute())
                }
            }
            .chartYScale(domain: stockVolumeRange())
        }
    }

    private func stockVolumeRange() -> ClosedRange<Int> {
        let volumes = webSocketManager.stockVolumes.map { $0.volume }

        guard let maxVolume = volumes.max(), maxVolume > 0 else {
            return 0...10 // Default range if no data or all zero
        }

        let padding = max(Int(Double(maxVolume) * 0.1), 1)
        let upperBound = maxVolume + padding

        return 0...upperBound
    }
}
