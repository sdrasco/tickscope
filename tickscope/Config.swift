import Foundation

struct Config {
    static var polygonAPIKey: String {
        return KeychainManager.getAPIKey() ?? "NO_API_KEY"
    }

    static let stockWebSocketURL = "wss://socket.polygon.io/stocks"
    static let optionWebSocketURL = "wss://socket.polygon.io/options"
    
    static let stockDataRetention: TimeInterval = 180   // 300 = 5 minutes
    static let optionDataRetention: TimeInterval = 300 // 1800 = 30 minutes
}
