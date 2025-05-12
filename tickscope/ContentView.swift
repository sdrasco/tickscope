import SwiftUI

struct ContentView: View {
    @StateObject private var webSocketManager = IBKRWebSocketManager()
    @State private var optionTicker: String = "NVDA250328C00131000"
    @State private var isTracking: Bool = false
    @State private var displayedTitle: String = "Tickscope"
    @State private var stockConid: Int? = nil   // underlying stock ID once resolved
    @State private var optionConid: Int? = nil   // resolved option ID

    var body: some View {
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
                    TickerEntryView(ticker: $optionTicker) {
                        let uppercaseTicker = optionTicker.uppercased()
                        print("🎯 Scope pressed with ticker:", uppercaseTicker)

                        Task {
                            do {
                                async let optionId = ContractLookup.optionConId(for: uppercaseTicker)
                                async let stockId  = ContractLookup.stockConId(for: extractStockSymbol(from: uppercaseTicker))
                                let optID   = try await optionId
                                let stkID   = try await stockId

                                stockConid  = stkID
                                optionConid = optID
                                webSocketManager.connect(conIds: [stkID, optID])
                                isTracking = true
                                displayedTitle = "Tickscope: \(formatOptionDetails(from: uppercaseTicker))"
                            } catch {
                                // TODO: surface this in the UI
                                print("Contract lookup failed:", error)
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
