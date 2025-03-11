//
//  VolumeOptionChartView.swift
//  TickscopeSwift
//
//  Created by sdrasco on 10/03/2025.
//


import SwiftUI
import Charts

struct VolumeOptionChartView: View {
    @ObservedObject var webSocketManager: WebSocketManager

    var body: some View {
        VStack {
            Text("Option Trade Volume")
                .font(.headline)
                .padding()

            Chart {
                ForEach(webSocketManager.optionVolumes, id: \.timestamp) { volume in
                    BarMark(
                        x: .value("Time", volume.timestamp),
                        y: .value("Volume", volume.volume)
                    )
                    .foregroundStyle(.orange)
                }
            }
        }
    }
}
