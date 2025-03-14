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
            Text("Option Trade Volume (contracts)")
                .font(.headline)
                .padding()
            
            Chart(webSocketManager.optionVolumes, id: \.id) { volume in
                BarMark(
                    x: .value("Time", volume.timestamp),
                    y: .value("Volume", volume.volume)
                )
                .foregroundStyle(.orange)
            }
            .chartYScale(domain: optionVolumeRange())
        }
    }
    
    private func optionVolumeRange() -> ClosedRange<Int> {
        let volumes = webSocketManager.optionVolumes.map { $0.volume }
        
        guard let maxVolume = volumes.max(), maxVolume > 0 else {
            return 0...10 // Default range if no data or all zero
        }
        
        let padding = max(Int(Double(maxVolume) * 0.1), 1)
        let upperBound = maxVolume + padding

        return 0...upperBound
    }
}
