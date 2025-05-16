//
//  TickerEntryView.swift
//  tickscope
//
//  Created by sdrasco on 14/03/2025.
//

//
//  TickerEntryView.swift
//  tickscope
//
//  A tiny form that lets the user paste an OCC/Polygon option‑ticker string,
//  validates it locally, and passes a `TickerInput` upstream.  Any parse
//  issues are shown inline so the user doesn’t have to wait for the network
//  layer to complain.
//

import SwiftUI

struct TickerEntryView: View {
    @Binding var tickerText: String
    var onScope: (TickerInput) -> Void

    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .trailing, spacing: 4) {
            HStack {
                Spacer()

                TextField("Option Ticker (e.g. TSLA250404P00200000)", text: $tickerText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 220)
                    .onSubmit(scopeTapped)

                Button("Scope it!", action: scopeTapped)
                    .keyboardShortcut(.defaultAction)
            }
            .frame(height: 30)

            if let msg = errorMessage {
                Text(msg)
                    .foregroundColor(.red)
                    .font(.caption2)
                    .transition(.opacity)
            }
        }
    }

    private func scopeTapped() {
        let trimmed = tickerText.trimmingCharacters(in: .whitespacesAndNewlines).uppercased()

        do {
            try validateOCC(trimmed)
            errorMessage = nil
            onScope(.occ(trimmed))
        } catch let err as InputError {
            errorMessage = err.errorDescription
        } catch {
            errorMessage = "Unexpected error: \(error.localizedDescription)"
        }
    }

    /// Local OCC‑format sanity check (length, YYMMDD, strike, C/P flag).
    private func validateOCC(_ s: String) throws {
        // OCC strings may be 16–21 characters (root 1‑6 + YYMMDD + C/P + 8‑digit strike)
        guard (16...21).contains(s.count) else { throw InputError.length }

        let pattern = #"^([A-Z]{1,6})(\d{6})([CP])([A-Z0-9]{8})$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              regex.firstMatch(in: s, range: NSRange(location: 0, length: s.utf16.count)) != nil
        else { throw InputError.badFlag }

        // Date validation (YYMMDD) — capture group 2
        guard
            let match = regex.firstMatch(in: s,
                                         range: NSRange(location: 0, length: s.utf16.count))
        else { throw InputError.badFlag }

        let dateRange = match.range(at: 2)
        guard let swiftRange = Range(dateRange, in: s) else { throw InputError.badDate }
        let dateStr = String(s[swiftRange])

        let df = DateFormatter(); df.dateFormat = "yyMMdd"; df.timeZone = .gmt
        guard df.date(from: dateStr) != nil else { throw InputError.badDate }

        // Strike numeric check
        let strikeStr = String(s.suffix(8))
        guard Int(strikeStr) != nil else { throw InputError.badStrike }
    }
}
