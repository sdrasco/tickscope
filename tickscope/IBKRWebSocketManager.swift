//
//  IBKRWebSocketManager.swift
//  tickscope
//
//  Created in the IBKR-swift-version branch
//

import Foundation
import Combine

/// Market-data field IDs we care about for the first pass.
/// 31 = last trade price, 84 = bid, 85 = ask, 3 = last size, 8 = volume.
private let defaultFieldIDs = "31,84,85,3,8"

@MainActor
final class IBKRWebSocketManager: ObservableObject {

    // MARK: - Published output (wire these to your charts later)
    /// Keep only the most recent N seconds of data (uses Config’s stock interval for now)
    private let retentionSeconds: TimeInterval = Config.stockDataRetention
    @Published var trades:  [TradeDatum]  = []
    @Published var quotes:  [QuoteDatum]  = []
    @Published var volumes: [VolumeDatum] = []

    // MARK: - Private
    private var webSocketTask: URLSessionWebSocketTask?
    private var cancellables = Set<AnyCancellable>()

    // MARK: - Public API
    /// Call this after you have the conId(s) you want to stream.
    func connect(conIds: [Int]) {
        guard webSocketTask == nil else { return }   // already connected

        let url = Config.websocketURL
        let session = URLSession(configuration: .default,
                                 delegate: LocalhostTLSDelegate(),
                                 delegateQueue: nil)

        webSocketTask = session.webSocketTask(with: url)
        webSocketTask?.resume()

        // Subscribe as soon as the socket opens
        let destination = "MarketData"
        let message: [String: Any] = [
            "destination": destination,
            "conids": conIds.map(String.init),
            "fields": defaultFieldIDs
        ]
        send(json: message)

        listen()    // start reading frames
    }

    func disconnect() {
        webSocketTask?.cancel(with: .goingAway, reason: nil)
        webSocketTask = nil
    }

    // MARK: - Helpers
    private func listen() {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(.string(let text)):
                self.handle(raw: text)

            case .success(.data(let data)):
                if let text = String(data: data, encoding: .utf8) {
                    self.handle(raw: text)
                }

            case .failure(let error):
                print("WS receive error:", error)
                self.disconnect()
            @unknown default:
                break
            }

            // Re-arm the listener for the next frame
            self.listen()
        }
    }

    private func send(json: [String: Any]) {
        guard let data = try? JSONSerialization.data(withJSONObject: json),
              let string = String(data: data, encoding: .utf8) else { return }
        webSocketTask?.send(.string(string)) { error in
            if let error { print("WS send error:", error) }
        }
    }

    /// Drop any elements older than `retentionSeconds`
    private func trimOldData(now: Date = Date()) {
        let cutoff = now.addingTimeInterval(-retentionSeconds)
        trades.removeAll  { $0.timestamp < cutoff }
        quotes.removeAll  { $0.timestamp < cutoff }
        volumes.removeAll { $0.timestamp < cutoff }
    }

    private func handle(raw text: String) {
        guard
            let data = text.data(using: .utf8),
            let objects = try? JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { return }

        for obj in objects {
            // conid is either an Int or a String
            guard let conid = (obj["conid"] as? String).flatMap(Int.init) ?? obj["conid"] as? Int else { continue }

            // Field 7 is epoch‑ms; fall back to "now" if absent
            let tsMillis = (obj["7"] as? Double)
                        ?? (obj["7"] as? NSNumber)?.doubleValue
            let timestamp = tsMillis != nil
                ? Date(timeIntervalSince1970: tsMillis! / 1_000)
                : Date()

            // -------- Trade (31 = last price, 3 = last size) --------
            if let priceStr = obj["31"] as? String,
               let price    = Double(priceStr) {

                let size = (obj["3"] as? String).flatMap(Int.init)
                       ?? (obj["3"] as? NSNumber)?.intValue

                trades.append(
                    TradeDatum(conid: conid,
                               price: price,
                               size:  size,
                               timestamp: timestamp)
                )
            }

            // -------- Quote (84 = bid, 85 = ask) --------
            if obj["84"] != nil || obj["85"] != nil {
                let bid = (obj["84"] as? String).flatMap(Double.init)
                       ?? (obj["84"] as? NSNumber)?.doubleValue
                let ask = (obj["85"] as? String).flatMap(Double.init)
                       ?? (obj["85"] as? NSNumber)?.doubleValue

                quotes.append(
                    QuoteDatum(conid: conid,
                               bid: bid,
                               ask: ask,
                               timestamp: timestamp)
                )
            }

            // -------- Volume (8 = cum volume) --------
            if let volStr = obj["8"] as? String,
               let vol    = Int(volStr) {

                volumes.append(
                    VolumeDatum(conid: conid,
                                volume: vol,
                                timestamp: timestamp)
                )
            }
        }

        trimOldData()
    }
}

/// Accept localhost / self-signed certs so ATS doesn’t block the socket.
/// Remove this if you proxy through valid TLS.
private final class LocalhostTLSDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential, URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
}

/// Parsed model structs ----------------------------------------------------

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
