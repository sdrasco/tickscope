import Foundation

struct Config {
    static let websocketURL = URL(string: "wss://localhost:5000/v1/api/ws")!
    static let restBaseURL  = URL(string: "https://localhost:5000/v1/api")!

    static let stockDataRetention: TimeInterval = 180   // 300 = 5 minutes
    static let optionDataRetention: TimeInterval = 300 // 1800 = 30 minutes
}
