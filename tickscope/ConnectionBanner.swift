//
//  ConnectionBanner.swift
//  tickscope
//
//  Created by sdrasco on 16/05/2025.
//


//
//  ConnectionBanner.swift
//  tickscope
//
//  A tiny SwiftUI pill that reflects the WebSocket connection state.
//

import SwiftUI

struct ConnectionBanner: View {
    let status: ConnectionStatus
    let error: Error?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: iconName)
            Text(label)
                .font(.caption.bold())
            if let err = error {
                Text(err.localizedDescription)
                    .font(.caption2)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .foregroundStyle(.white)
        .background(backgroundColor)
        .clipShape(Capsule())
        .shadow(radius: 2)
        .animation(.easeInOut, value: status)
    }

    // MARK: – Helpers ----------------------------------------------------

    private var iconName: String {
        switch status {
        case .connected:    "checkmark.circle.fill"
        case .connecting:   "arrow.triangle.2.circlepath.circle.fill"
        case .disconnected: error == nil ? "circle.fill" : "exclamationmark.triangle.fill"
        }
    }

    private var label: String {
        switch status {
        case .connected:    "Connected"
        case .connecting:   "Connecting…"
        case .disconnected: error == nil ? "Disconnected" : "Error"
        }
    }

    private var backgroundColor: Color {
        switch status {
        case .connected:    .green
        case .connecting:   .yellow
        case .disconnected: error == nil ? .gray : .red
        }
    }
}