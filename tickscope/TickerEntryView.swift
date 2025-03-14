//
//  TickerEntryView.swift
//  tickscope
//
//  Created by sdrasco on 14/03/2025.
//


import SwiftUI

struct TickerEntryView: View {
    @Binding var ticker: String
    var onScope: () -> Void

    var body: some View {
        HStack {
            Spacer()
            TextField("Option Ticker", text: $ticker)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .frame(width: 200)

            Button("Scope it!") {
                onScope()
            }
        }
        .frame(height: 30)
    }
}
