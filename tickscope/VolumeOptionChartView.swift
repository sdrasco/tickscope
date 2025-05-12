//
//  VolumeOptionChartView.swift
//  TickscopeSwift
//
//  Created by sdrasco on 10/03/2025.
//  IBKR-adapted on 09/05/2025
//

import SwiftUI
import Charts

struct VolumeOptionChartView: View {
    /// IBKR streaming manager (replaces the old Polygon WebSocketManager)
    @ObservedObject var webSocketManager: IBKRWebSocketManager
    
    /// conId of the option contract we’re charting
    let optionConid: Int
    
    var body: some View {
        VStack {
            Text("Option Trade Volume (contracts)")
                .font(.headline)
                .padding()
            
            // Plot only the option’s volume stream
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
    
    /// Only volume ticks that belong to this option
    private var filteredVolumes: [VolumeDatum] {
        webSocketManager.volumes.filter { $0.conid == optionConid }
    }
    
    /// Build a sensible y-axis based on the latest volume window.
    private func volumeRange() -> ClosedRange<Int> {
        let vols = filteredVolumes.map(\.volume)
        guard let maxVol = vols.max(), maxVol > 0 else { return 0...10 }
        
        let padding  = max(Int(Double(maxVol) * 0.1), 1)
        return 0...(maxVol + padding)
    }
}
