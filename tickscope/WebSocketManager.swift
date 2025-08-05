import Foundation

// FFI declarations for native pricing models
@_silgen_name("baw_price_ffi")
func baw_price_ffi(_ input: UnsafePointer<COptionPricingInput>) -> Double

@_silgen_name("binomial_price_ffi")
func binomial_price_ffi(_ input: UnsafePointer<COptionPricingInput>, _ steps: Int32) -> Double

struct COptionPricingInput {
    var spot: Double
    var strike: Double
    var timeToExpiry: Double
    var impliedVol: Double
    var riskFreeRate: Double
    var optionType: Int32
    var dividendYield: Double
}

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

struct ModelPricePoint: Identifiable {
    let id = UUID()
    let model: String
    let price: Double
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
    @Published var modelPriceSeries: [ModelPricePoint] = []
    @Published var optionPricingInput = OptionPricingInput(
        spot: 0.0,
        strike: 0.0,
        timeToExpiry: 0.0,
        impliedVol: 0.0,
        riskFreeRate: 0.0,
        optionType: .call,
        dividendYield: nil
    )
    var optionPricingPublisher: Published<OptionPricingInput>.Publisher { $optionPricingInput }

    private var stockWebSocket: URLSessionWebSocketTask?
    private var optionWebSocket: URLSessionWebSocketTask?
    private let session = URLSession(configuration: .default)
    private var modelPriceTimer: Timer?

    /// ✅ Centralized function to reset all chart data
    private func resetData() {
        DispatchQueue.main.async {
            self.tradePrices.removeAll()
            self.optionTradePrices.removeAll()
            self.bidAskStockPrices.removeAll()
            self.bidAskOptionPrices.removeAll()
            self.stockVolumes.removeAll()
            self.optionVolumes.removeAll()
            self.modelPriceSeries.removeAll()

            self.latestStockMessage = "No stock data yet"
            self.latestOptionMessage = "No option data yet"
            self.optionPricingInput = OptionPricingInput(
                spot: 0.0,
                strike: 0.0,
                timeToExpiry: 0.0,
                impliedVol: 0.0,
                riskFreeRate: 0.0,
                optionType: .call,
                dividendYield: nil
            )
            self.modelPriceTimer?.invalidate()
            self.modelPriceTimer = nil
        }
    }

    /// ✅ Calls `resetData()` before connecting to a new ticker
    func connect(stockTicker: String, optionTicker: String) {
        // Cancel any existing tasks so they don't continue running when reconnecting
        disconnect()
        resetData() // Clear all data before reconnecting

        connectStockWebSocket(stockTicker: stockTicker)
        connectOptionWebSocket(optionTicker: optionTicker)
        startModelPriceTimer()
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

    private func startModelPriceTimer() {
        modelPriceTimer?.invalidate()
        modelPriceTimer = Timer.scheduledTimer(withTimeInterval: Config.modelPriceRefresh, repeats: true) { [weak self] _ in
            self?.updateModelPrices()
        }
    }

    private func updateModelPrices() {
        let input = optionPricingInput
        let cInput = COptionPricingInput(
            spot: input.spot,
            strike: input.strike,
            timeToExpiry: input.timeToExpiry,
            impliedVol: input.impliedVol,
            riskFreeRate: input.riskFreeRate,
            optionType: input.optionType == .call ? 0 : 1,
            dividendYield: input.dividendYield ?? 0.0
        )

        var baw: Double = 0.0
        var bin: Double = 0.0
        withUnsafePointer(to: cInput) { ptr in
            baw = baw_price_ffi(ptr)
            bin = binomial_price_ffi(ptr, 200)
        }

        let now = Date()
        DispatchQueue.main.async {
            self.modelPriceSeries.append(ModelPricePoint(model: "BAW", price: baw, timestamp: now))
            self.modelPriceSeries.append(ModelPricePoint(model: "Binomial", price: bin, timestamp: now))

            let cutoff = Date().addingTimeInterval(-Config.optionDataRetention)
            self.modelPriceSeries.removeAll { $0.timestamp < cutoff }
        }
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
                                let volumeData = VolumeData(volume: size, timestamp: Date())

                                DispatchQueue.main.async {
                                    self.tradePrices.append(trade)
                                    self.stockVolumes.append(volumeData) //
                                    self.optionPricingInput.spot = price

                                    // Keep only the last X seconds of data
                                    let cutoffTime = Date().addingTimeInterval(-Config.stockDataRetention)
                                    self.tradePrices.removeAll { $0.timestamp < cutoffTime }
                                    self.stockVolumes.removeAll { $0.timestamp < cutoffTime }
                                }
                            }
                        case "Q": // Quote event
                            if let bid = message["bp"] as? Double, let ask = message["ap"] as? Double {
                                let quote = BidAskQuote(bidPrice: bid, askPrice: ask, timestamp: Date())
                                DispatchQueue.main.async {
                                    self.bidAskStockPrices.append(quote)
                                    self.bidAskStockPrices.removeAll { $0.timestamp < Date().addingTimeInterval(-Config.stockDataRetention) }
                                }
                            }
                        default:
                            break
                        }
                    }
                }
            }
            updateOptionChartsTimestamp()
        } catch {
            print("Failed to parse stock message: \(error)")
        }
    }

    private func parseOptionMessage(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }
        do {
            if let jsonArray = try JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any]] {
                for message in jsonArray {
                    if let iv = message["iv"] as? Double {
                        DispatchQueue.main.async { self.optionPricingInput.impliedVol = iv }
                    }
                    if let strike = message["k"] as? Double {
                        DispatchQueue.main.async { self.optionPricingInput.strike = strike }
                    }
                    if let expiry = message["x"] as? String,
                       let date = ISO8601DateFormatter().date(from: expiry) {
                        let t = max(0, date.timeIntervalSince(Date()) / (365.0 * 24.0 * 3600.0))
                        DispatchQueue.main.async { self.optionPricingInput.timeToExpiry = t }
                    }
                    if let type = message["c"] as? String {
                        let optType: OptionType = type.uppercased() == "C" ? .call : .put
                        DispatchQueue.main.async { self.optionPricingInput.optionType = optType }
                    }
                    if let rate = message["r"] as? Double {
                        DispatchQueue.main.async { self.optionPricingInput.riskFreeRate = rate }
                    }
                    if let div = message["d"] as? Double {
                        DispatchQueue.main.async { self.optionPricingInput.dividendYield = div }
                    }
                    if let event = message["ev"] as? String {
                        switch event {
                        case "T": // Trade event (captures volume)
                            if let price = message["p"] as? Double,
                               let size = message["s"] as? Int {
                                let trade = Trade(price: price, timestamp: Date())
                                let volumeData = VolumeData(volume: size, timestamp: Date())

                                DispatchQueue.main.async {
                                    self.optionTradePrices.append(trade)
                                    self.optionVolumes.append(volumeData)

                                    // Keep only the last X seconds of data
                                    let cutoffTime = Date().addingTimeInterval(-Config.optionDataRetention)
                                    self.optionTradePrices.removeAll { $0.timestamp < cutoffTime }
                                    self.optionVolumes.removeAll { $0.timestamp < cutoffTime }
                                }
                            }
                        case "Q": // Quote event
                            if let bid = message["bp"] as? Double, let ask = message["ap"] as? Double {
                                let quote = BidAskQuote(bidPrice: bid, askPrice: ask, timestamp: Date())
                                DispatchQueue.main.async {
                                    self.bidAskOptionPrices.append(quote)
                                    self.bidAskOptionPrices.removeAll { $0.timestamp < Date().addingTimeInterval(-Config.optionDataRetention) }
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
        stockWebSocket = nil
        optionWebSocket?.cancel()
        optionWebSocket = nil
        modelPriceTimer?.invalidate()
        modelPriceTimer = nil
    }
    
    private func updateOptionChartsTimestamp() {
        let cutoffTime = Date().addingTimeInterval(-Config.optionDataRetention)
    
        DispatchQueue.main.async {
            self.optionTradePrices.removeAll { $0.timestamp < cutoffTime }
            self.optionVolumes.removeAll { $0.timestamp < cutoffTime }
            self.bidAskOptionPrices.removeAll { $0.timestamp < cutoffTime }
        }
    }
}
