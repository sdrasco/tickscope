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
                ForEach(webSocketManager.stockVolumes, id: \.timestamp) { volume in
                    BarMark(
                        x: .value("Time", volume.timestamp),
                        y: .value("Volume", volume.volume)
                    )
                    .foregroundStyle(.blue)
                }
            }
        }
    }
}
