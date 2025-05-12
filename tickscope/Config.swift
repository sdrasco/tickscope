import Foundation

struct Config {
    static let websocketURL = URL(string: "wss://127.0.0.1:5010/v1/api/ws")!
    static let restBaseURL  = URL(string: "https://127.0.0.1:5010/v1/api")!

    static let stockDataRetention: TimeInterval = 180   // 300 = 5 minutes
    static let optionDataRetention: TimeInterval = 300 // 1800 = 30 minutes
}
