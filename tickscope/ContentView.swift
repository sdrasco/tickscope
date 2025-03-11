import SwiftUI

struct ContentView: View {
    @StateObject private var webSocketManager = WebSocketManager()
    @State private var optionTicker: String = "TSLA250314P00240000"
    @State private var isTracking: Bool = false
    @State private var displayedTitle: String = "Tickscope"

    var body: some View {
        HStack(alignment: .top, spacing: 20) {
            VStack(alignment: .leading, spacing: 20) {
                
                Text(displayedTitle)
                    .font(.title)
                    .fontWeight(.bold)
                    .frame(height: 30)

                StockPriceChartView(webSocketManager: webSocketManager)
                    .frame(height: 250)
                BidAskStockChartView(webSocketManager: webSocketManager)
                    .frame(height: 250)
                VolumeStockChartView(webSocketManager: webSocketManager)
                    .frame(height: 250)

                Spacer()
            }

            VStack(alignment: .trailing, spacing: 20) {
                HStack {
                    Spacer()

                    TextField("Option Ticker", text: $optionTicker)
                        .textFieldStyle(RoundedBorderTextFieldStyle())
                        .frame(width: 200)

                    Button("Scope it!") {
                        let stockTicker = extractStockSymbol(from: optionTicker)
                        webSocketManager.connect(stockTicker: stockTicker, optionTicker: optionTicker)
                        isTracking = true
                        displayedTitle = "Tickscope: \(formatOptionDetails(from: optionTicker))"
                    }
                }
                .frame(height: 30)

                OptionPriceChartView(webSocketManager: webSocketManager)
                    .frame(height: 250)
                BidAskOptionChartView(webSocketManager: webSocketManager)
                    .frame(height: 250)
                VolumeOptionChartView(webSocketManager: webSocketManager)
                    .frame(height: 250)

                Spacer()
            }
        }
        .padding()
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
