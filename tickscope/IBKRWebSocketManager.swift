//
//  IBKRWebSocketManager.swift
//  tickscope
//

import Foundation
import Combine

// MARK: – Connection state exposed to UI
enum ConnectionStatus { case disconnected, connecting, connected }

// MARK: – Field set
/// 31 = last trade, 83 = last trade (alt)
/// 84 = bid, 85 = ask
/// 3 / 66 = last size, 8 = cum volume
private let defaultFieldIDs = "31,83,84,85,66,3,8"

// Session used for REST calls such as market data unsubscribe
private let restSession: URLSession = {
    URLSession(configuration: .default,
               delegate: LocalhostTLSDelegate(),
               delegateQueue: nil)
}()

@MainActor
final class IBKRWebSocketManager: ObservableObject {

    // MARK: Published series
    private let retentionSeconds: TimeInterval = Config.stockDataRetention
    @Published var trades:  [TradeDatum]  = []
    @Published var quotes:  [QuoteDatum]  = []
    @Published var volumes: [VolumeDatum] = []

    @Published var status: ConnectionStatus = .disconnected
    @Published var connectionError: Error?

    private var webSocketTask: URLSessionWebSocketTask?

    /// Session token returned by the Gateway `system` topic
    private var sessionToken: String?

    /// Market-data subscriptions waiting for a session token
    private var pendingConIds: [Int] = []

    // MARK: Public API
    func connect(conIds: [Int]) {
        if webSocketTask != nil { disconnect() }
        clearAllData()
        connectionError = nil
        sessionToken = nil
        pendingConIds = conIds
        status = .connecting

        let session = URLSession(configuration: .default,
                                 delegate: LocalhostTLSDelegate(),
                                 delegateQueue: nil)
        let url = Config.websocketURL
        webSocketTask = session.webSocketTask(with: url)
        let conIdString = conIds.map(String.init).joined(separator: ",")
        print("🌐 WS connecting to", url, "for", conIdString)
        webSocketTask?.resume()
        status = .connected

        if sessionToken != nil {
            subscribe(conIds: conIds)
        }
        listen()
    }

    func disconnect() {
        // Attempt to cancel all market-data streams
        Task {
            var url = Config.restBaseURL.appendingPathComponent("/iserver/marketdata/unsubscribeall")
            var req = URLRequest(url: url); req.timeoutInterval = 8
            _ = try? await restSession.data(for: req)
        }
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
        sessionToken = nil
        pendingConIds.removeAll()
        status = .disconnected
    }

    // MARK: Helpers
    private func clearAllData() { trades.removeAll(); quotes.removeAll(); volumes.removeAll() }

    private func listen() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }
            switch result {

            case .success(.string(let text)):
                Task { @MainActor in self.handleMarketData(text) }

            case .success(.data(let data)):
                // ── NEW: peek at every binary/text frame first ─────────────
                print("🧱 raw frame (\(data.count) bytes):",
                      String(data: data.prefix(120), encoding: .utf8) ?? "<binary>")
                // -----------------------------------------------------------
                if let text = String(data: data, encoding: .utf8) {
                    Task { @MainActor in self.handleMarketData(text) }
                }

            case .failure(let err):
                self.connectionError = err
                self.disconnect()

            @unknown default: break
            }
            self.listen()
        }
    }

    /// Send a raw text frame to the WebSocket.
    private func sendText(_ text: String) {
        webSocketTask?.send(.string(text)) { if let e = $0 { self.connectionError = e } }
    }

    /// Send a market-data subscription once a session token exists.
    private func subscribe(conIds: [Int]) {
        guard let sessionToken else {
            pendingConIds = conIds
            return
        }
        let conIdString = conIds.map(String.init).joined(separator: ",")
        let frame = "smd+\(conIdString)+\(defaultFieldIDs)+\(sessionToken)"
        sendText(frame)
    }

    private func trimOldData(now: Date = .init()) {
        let cut = now.addingTimeInterval(-retentionSeconds)
        trades.removeAll  { $0.timestamp < cut }
        quotes.removeAll  { $0.timestamp < cut }
        volumes.removeAll { $0.timestamp < cut }
    }

    // MARK: Frame parsing
    private func handleMarketData(_ text: String) {
        guard let data = text.data(using: .utf8) else { return }

        if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let topic = obj["topic"] as? String, topic == "system",
               let token = obj["success"] as? String {
                sessionToken = token
                if !pendingConIds.isEmpty {
                    subscribe(conIds: pendingConIds)
                    pendingConIds.removeAll()
                }
                return
            }
            parseMarketData(obj); trimOldData(); return
        }

        if let arr = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]] {
            arr.forEach(parseMarketData); trimOldData(); return
        }

        print("❌ Un-parsable frame:", text.prefix(120))
    }

    /// Parse one market-data JSON object and append to arrays.
    private func parseMarketData(_ obj: [String: Any]) {

        guard let conid = (obj["conid"] as? String).flatMap(Int.init)
               ?? obj["conid"] as? Int else { return }

        let tsMillis = (obj["7"] as? Double)
                    ?? (obj["7"] as? NSNumber)?.doubleValue
        let ts = tsMillis.map { Date(timeIntervalSince1970: $0 / 1_000) } ?? Date()

        func asDouble(_ v: Any?) -> Double? {
            switch v {
            case let s as String:   Double(s)
            case let n as NSNumber: n.doubleValue
            default: nil
            }
        }
        func asInt(_ v: Any?) -> Int? {
            switch v {
            case let s as String:   Int(s)
            case let n as NSNumber: n.intValue
            default: nil
            }
        }

        // Trade
        if let price = asDouble(obj["31"]) ?? asDouble(obj["83"]) {
            let size = asInt(obj["3"]) ?? asInt(obj["66"])
            trades.append(.init(conid: conid, price: price, size: size, timestamp: ts))
            print("📈 trade", conid, price, size ?? 0, "@", ts)
        }

        // Quote
        if obj["84"] != nil || obj["85"] != nil {
            let bid = asDouble(obj["84"])
            let ask = asDouble(obj["85"])
            quotes.append(.init(conid: conid, bid: bid, ask: ask, timestamp: ts))
        }

        // Volume
        if let vol = asInt(obj["8"]) {
            volumes.append(.init(conid: conid, volume: vol, timestamp: ts))
        }
    }
}

// MARK: – Localhost TLS bypass
private final class LocalhostTLSDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ s: URLSession, didReceive c: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential,
                          URLCredential(trust: c.protectionSpace.serverTrust!))
    }
}

// MARK: – Data models
struct TradeDatum: Identifiable {
    let id = UUID()
    let conid: Int
    let price: Double
    let size: Int?
    let timestamp: Date
}
struct QuoteDatum: Identifiable {
    let id = UUID()
    let conid: Int
    let bid: Double?
    let ask: Double?
    let timestamp: Date
}
struct VolumeDatum: Identifiable {
    let id = UUID()
    let conid: Int
    let volume: Int
    let timestamp: Date
}
