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
        
        guard let minVolume = volumes.min(), let maxVolume = volumes.max() else {
            return 0...10 // sensible default if no data present
        }
        
        let safeMinVolume = max(minVolume, 0)
        
        if minVolume == maxVolume {
            let padding = max(Int(Double(minVolume) * 0.1), 1)
            let lowerBound = max(0, minVolume - padding)
            let upperBound = minVolume + padding
            return lowerBound...upperBound
        } else {
            let padding = max(Int(Double(maxVolume - minVolume) * 0.1), 1)
            let lowerBound = max(0, minVolume - padding)
            return lowerBound...(maxVolume + padding)
        }
    }
}
