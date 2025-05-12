//
//  VolumeStockChartView.swift
//  TickscopeSwift
//
//  Created by sdrasco on 10/03/2025.
//  IBKR-adapted on 09/05/2025
//

import SwiftUI
import Charts

struct VolumeStockChartView: View {
    /// IBKR streaming manager (replaces Polygon WebSocketManager)
    @ObservedObject var webSocketManager: IBKRWebSocketManager
    let stockConid: Int          // specific stock to display

    private var filteredVolumes: [VolumeDatum] {
        webSocketManager.volumes.filter { $0.conid == stockConid }
    }

    var body: some View {
        VStack {
            Text("Stock Trade Volume (shares)")
                .font(.headline)
                .padding()

            Chart(filteredVolumes, id: \.id) { volume in
                BarMark(
                    x: .value("Time", volume.timestamp),
                    y: .value("Volume", volume.volume)
                )
                .opacity(0.6)
            }
            .chartYScale(domain: volumeRange())
        }
    }

    /// Build a reasonable y-axis based on the live window.
    private func volumeRange() -> ClosedRange<Int> {
        let vols = filteredVolumes.map(\.volume)
        guard let maxVol = vols.max(), maxVol > 0 else { return 0...10 }

        let padding  = max(Int(Double(maxVol) * 0.1), 1)
        return 0...(maxVol + padding)
    }
}
