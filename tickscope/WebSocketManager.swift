import Foundation

struct Trade: Identifiable {
    let id = UUID()
    let price: Double
    let timestamp: Date
}

struct BidAskQuote: Identifiable {
    let id = UUID()
    let bidPrice: Double
    let askPrice: Double
    let timestamp: Date
}

struct VolumeData: Identifiable {
    let id = UUID()
    let volume: Int
    let timestamp: Date
}

class WebSocketManager: ObservableObject {
    @Published var latestStockMessage: String = "No stock data yet"
    @Published var tradePrices: [Trade] = []
    @Published var bidAskStockPrices: [BidAskQuote] = []
    @Published var stockVolumes: [VolumeData] = []

    @Published var latestOptionMessage: String = "No option data yet"
    @Published var optionTradePrices: [Trade] = []
    @Published var bidAskOptionPrices: [BidAskQuote] = []
    @Published var optionVolumes: [VolumeData] = []

    private var stockWebSocket: URLSessionWebSocketTask?
    private var optionWebSocket: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)

    /// ✅ Centralized function to reset all chart data
    private func resetData() {
        DispatchQueue.main.async {
            self.tradePrices.removeAll()
            self.optionTradePrices.removeAll()
            self.bidAskStockPrices.removeAll()
            self.bidAskOptionPrices.removeAll()
            self.stockVolumes.removeAll()
            self.optionVolumes.removeAll()

            self.latestStockMessage = "No stock data yet"
            self.latestOptionMessage = "No option data yet"
        }
    }

    /// ✅ Calls `resetData()` before connecting to a new ticker
    func connect(stockTicker: String, optionTicker: String) {
        resetData() // Clear all data before reconnecting

        connectStockWebSocket(stockTicker: stockTicker)
        connectOptionWebSocket(optionTicker: optionTicker)
    }

    private func connectStockWebSocket(stockTicker: String) {
        guard let url = URL(string: Config.stockWebSocketURL) else { return }
        stockWebSocket = session.webSocketTask(with: url)
        stockWebSocket?.resume()

        authenticate(webSocket: stockWebSocket!)
        subscribeToStockData(ticker: stockTicker)
        receiveStockMessages()
    }

    private func connectOptionWebSocket(optionTicker: String) {
        guard let url = URL(string: Config.optionWebSocketURL) else { return }
        optionWebSocket = session.webSocketTask(with: url)
        optionWebSocket?.resume()

        authenticate(webSocket: optionWebSocket!)
        subscribeToOptionData(ticker: optionTicker)
        receiveOptionMessages()
    }

    private func authenticate(webSocket: URLSessionWebSocketTask) {
        let authMessage = ["action": "auth", "params": Config.polygonAPIKey]
        sendMessage(authMessage, webSocket: webSocket)
    }

    private func subscribeToStockData(ticker: String) {
        let subscribeMessage = ["action": "subscribe", "params": "T.\(ticker),Q.\(ticker)"]
        sendMessage(subscribeMessage, webSocket: stockWebSocket!)
    }

    private func subscribeToOptionData(ticker: String) {
        let subscribeMessage = ["action": "subscribe", "params": "T.O:\(ticker),Q.O:\(ticker)"]
        sendMessage(subscribeMessage, webSocket: optionWebSocket!)
    }

    private func sendMessage(_ message: [String: Any], webSocket: URLSessionWebSocketTask) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: message, options: []) else { return }
        let jsonString = String(data: jsonData, encoding: .utf8)!
        webSocket.send(.string(jsonString)) { error in
            if let error = error {
                print("WebSocket send error: \(error)")
            }
        }
    }

    private func receiveStockMessages() {
        stockWebSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    DispatchQueue.main.async {
                        self?.parseStockMessage(text)
                    }
                default:
                    break
                }
            case .failure(let error):
                print("Stock WebSocket error: \(error)")
            }
            self?.receiveStockMessages()
        }
    }

    private func receiveOptionMessages() {
        optionWebSocket?.receive { [weak self] result in
            switch result {
            case .success(let message):
                switch message {
                case .string(let text):
                    DispatchQueue.main.async {
                        self?.parseOptionMessage(text)
                    }
                default:
                    break
                }
            case .failure(let error):
                print("Option WebSocket error: \(error)")
            }
            self?.receiveOptionMessages()
        }
    }

    private func parseStockMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        do {
            if let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                for message in jsonArray {
                    if let event = message["ev"] as? String {
                        switch event {
                        case "T": // Trade event (captures volume)
                            if let price = message["p"] as? Double,
                               let size = message["s"] as? Int {
                                let trade = Trade(price: price, timestamp: Date())
                                let volumeData = VolumeData(volume: size, timestamp: Date()) // ✅ Store volume

                                DispatchQueue.main.async {
                                    self.tradePrices.append(trade)
                                    self.stockVolumes.append(volumeData) // ✅ Store volume for stock trades

                                    // Keep only the last 60 seconds of data
                                    let cutoffTime = Date().addingTimeInterval(-60)
                                    self.tradePrices.removeAll { $0.timestamp < cutoffTime }
                                    self.stockVolumes.removeAll { $0.timestamp < cutoffTime }
                                }
                            }
                        case "Q": // Quote event
                            if let bid = message["bp"] as? Double, let ask = message["ap"] as? Double {
                                let quote = BidAskQuote(bidPrice: bid, askPrice: ask, timestamp: Date())
                                DispatchQueue.main.async {
                                    self.bidAskStockPrices.append(quote)
                                    self.bidAskStockPrices.removeAll { $0.timestamp < Date().addingTimeInterval(-60) }
                                }
                            }
                        default:
                            break
                        }
                    }
                }
            }
        } catch {
            print("Failed to parse stock message: \(error)")
        }
    }

    private func parseOptionMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        do {
            if let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                for message in jsonArray {
                    if let event = message["ev"] as? String {
                        switch event {
                        case "T": // Trade event (captures volume)
                            if let price = message["p"] as? Double,
                               let size = message["s"] as? Int {
                                let trade = Trade(price: price, timestamp: Date())
                                let volumeData = VolumeData(volume: size, timestamp: Date()) // ✅ Store volume

                                DispatchQueue.main.async {
                                    self.optionTradePrices.append(trade)
                                    self.optionVolumes.append(volumeData) // ✅ Store volume for options

                                    // Keep only the last 60 seconds of data
                                    let cutoffTime = Date().addingTimeInterval(-60)
                                    self.optionTradePrices.removeAll { $0.timestamp < cutoffTime }
                                    self.optionVolumes.removeAll { $0.timestamp < cutoffTime }
                                }
                            }
                        case "Q": // Quote event
                            if let bid = message["bp"] as? Double, let ask = message["ap"] as? Double {
                                let quote = BidAskQuote(bidPrice: bid, askPrice: ask, timestamp: Date())
                                DispatchQueue.main.async {
                                    self.bidAskOptionPrices.append(quote)
                                    self.bidAskOptionPrices.removeAll { $0.timestamp < Date().addingTimeInterval(-60) }
                                }
                            }
                        default:
                            break
                        }
                    }
                }
            }
        } catch {
            print("Failed to parse option message: \(error)")
        }
    }

    func disconnect() {
        stockWebSocket?.cancel()
        optionWebSocket?.cancel()
    }
}
