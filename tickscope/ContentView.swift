import SwiftUI

struct ContentView: View {
    // FUTURE: surface lookup/stream errors via @State var errorAlert: Error?
    @StateObject private var webSocketManager = IBKRWebSocketManager()
    @State private var optionTicker: String = "NVDA250328C00131000"
    @State private var displayedTitle: String = "Tickscope"
    @State private var stockConid: Int? = nil   // underlying stock ID once resolved
    @State private var optionConid: Int? = nil   // resolved option ID
    @State private var showBanner: Bool = true

    var body: some View {
        ZStack(alignment: .top) {
            ScrollView(.vertical) {
                HStack(alignment: .top, spacing: 20) {
                    // Left column
                    VStack(alignment: .leading, spacing: 20) {
                        Text(displayedTitle)
                            .font(.title)
                            .fontWeight(.bold)
                            .frame(height: 30)

                        if let stockID = stockConid {
                            StockPriceChartView(webSocketManager: webSocketManager,
                                                stockConid: stockID)
                                .frame(height: 250)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.05)))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        }

                        if let stockID = stockConid {
                            BidAskStockChartView(webSocketManager: webSocketManager,
                                                 stockConid: stockID)
                                .frame(height: 250)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 10)
                                              .fill(Color.gray.opacity(0.05)))
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                           .stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        }

                        if let stockID = stockConid {
                            VolumeStockChartView(webSocketManager: webSocketManager,
                                                 stockConid: stockID)
                                .frame(height: 250)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 10)
                                              .fill(Color.gray.opacity(0.05)))
                                .overlay(RoundedRectangle(cornerRadius: 10)
                                           .stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        }

                        Spacer()
                    }

                    // Right column
                    VStack(alignment: .trailing, spacing: 20) {
                        TickerEntryView(tickerText: $optionTicker) { input in
                            // Called after local validation passes
                            let occString: String
                            switch input {
                            case .occ(let s):       occString = s
                            case .components(let r, let d, let k, let right):
                                // Render components into standard OCC so we can reuse existing helpers.
                                let root6 = r.padding(toLength: 6, withPad: " ", startingAt: 0).uppercased()
                                let df = DateFormatter(); df.dateFormat = "yyMMdd"; df.timeZone = .gmt
                                let yyMMdd = df.string(from: d)
                                let strikeInt = Int((NSDecimalNumber(decimal: k).doubleValue * 1000).rounded())
                                let strikeField = String(format: "%08d", strikeInt)
                                occString = "\(root6)\(yyMMdd)\(right.uppercased())\(strikeField)"
                            }

                            print("🎯 Scope pressed with ticker:", occString)

                            Task {
                                do {
                                    async let optionId = ContractLookup.resolve(input)
                                    async let stockId  = ContractLookup.stockConId(for: extractStockSymbol(from: occString))
                                    let optID   = try await optionId
                                    let stkID   = try await stockId

                                    stockConid  = stkID
                                    optionConid = optID
                                    webSocketManager.connect(conIds: [stkID, optID])
                                    displayedTitle = "Tickscope: \(formatOptionDetails(from: occString))"
                                } catch let err as InputError {
                                    // Shouldn't occur—parsed earlier—but display just in case.
                                    print("Input error:", err)
                                } catch {
                                    print("Contract lookup failed:", error)
                                    // TODO: surface this in the UI
                                }
                            }
                        }

                        if let optID = optionConid {
                            OptionPriceChartView(webSocketManager: webSocketManager,
                                                 optionConid: optID)
                                .frame(height: 250)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.05)))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        }

                        if let optID = optionConid {
                            BidAskOptionChartView(optionConid: optID,
                                                  webSocketManager: webSocketManager)
                                .frame(height: 250)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.05)))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        }

                        if let optID = optionConid {
                            VolumeOptionChartView(webSocketManager: webSocketManager,
                                                  optionConid: optID)
                                .frame(height: 250)
                                .padding(8)
                                .background(RoundedRectangle(cornerRadius: 10).fill(Color.gray.opacity(0.05)))
                                .overlay(RoundedRectangle(cornerRadius: 10).stroke(Color.gray.opacity(0.3), lineWidth: 1))
                        }

                        Spacer()
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 15)
            }
            .onDisappear { webSocketManager.disconnect() }

            if showBanner {
                ConnectionBanner(status: webSocketManager.status,
                                 error: webSocketManager.connectionError)
                    .padding(.top, 8)
                    .padding(.horizontal)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .onTapGesture { withAnimation { showBanner.toggle() } } // tap to hide
            }
        }
    }
    
    private func extractStockSymbol(from optionTicker: String) -> String {
        let letters = optionTicker.prefix { $0.isLetter }
        return String(letters)
    }

    private func formatOptionDetails(from ticker: String) -> String {
        let pattern = #"^([A-Z]+)(\d{6})([CP])(\d{8})$"#
        let regex = try? NSRegularExpression(pattern: pattern)
        let nsTicker = ticker as NSString

        guard let match = regex?.firstMatch(in: ticker, range: NSRange(location: 0, length: nsTicker.length)),
              match.numberOfRanges == 5 else {
            return ticker
        }

        let stock = nsTicker.substring(with: match.range(at: 1))
        let dateString = nsTicker.substring(with: match.range(at: 2))
        let type = nsTicker.substring(with: match.range(at: 3)) == "C" ? "Call" : "Put"
        let strikeString = nsTicker.substring(with: match.range(at: 4))

        let formatter = DateFormatter()
        formatter.dateFormat = "yyMMdd"
        guard let date = formatter.date(from: dateString) else {
            return ticker
        }
        formatter.dateFormat = "d MMM yyyy"
        let formattedDate = formatter.string(from: date)

        let strikeValue = (Double(strikeString) ?? 0) / 1000.0
        let formattedStrike = strikeValue.truncatingRemainder(dividingBy: 1) == 0 ?
            String(format: "$%.0f", strikeValue) : String(format: "$%.2f", strikeValue)

        return "\(stock) \(type) at \(formattedStrike) expiring \(formattedDate)"
    }
}

#Preview {
    ContentView()
}
