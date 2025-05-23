import Foundation

// Helper to prime market data streaming via snapshot
enum MarketData {
    private static let snapshotFields = "31,83,84,85,66,3,8"

    // Session trusting the Gateway's self-signed cert
    private static let session: URLSession = {
        URLSession(configuration: .default,
                   delegate: LocalhostTLSDelegate(),
                   delegateQueue: nil)
    }()

    // Localhost TLS delegate identical to the ones used elsewhere
    private final class LocalhostTLSDelegate: NSObject, URLSessionDelegate {
        func urlSession(_ session: URLSession,
                        didReceive challenge: URLAuthenticationChallenge,
                        completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
            completionHandler(.useCredential,
                              URLCredential(trust: challenge.protectionSpace.serverTrust!))
        }
    }

    /// Issue /iserver/accounts and /iserver/marketdata/snapshot to start streaming data.
    static func requestSnapshot(conIds: [Int]) async throws {
        guard !conIds.isEmpty else { return }

        var url = Config.restBaseURL.appendingPathComponent("/iserver/accounts")
        var req = URLRequest(url: url); req.timeoutInterval = 8
        let (_, resp1) = try await session.data(for: req)
        if let http = resp1 as? HTTPURLResponse, http.statusCode != 200 {
            throw SnapshotError.server("HTTP \(http.statusCode)")
        }

        let conIdString = conIds.map(String.init).joined(separator: ",")
        url = Config.restBaseURL.appendingPathComponent("/iserver/marketdata/snapshot")
        url = url.appending("conids", value: conIdString)
        url = url.appending("fields", value: snapshotFields)

        req = URLRequest(url: url); req.timeoutInterval = 8
        let (_, resp2) = try await session.data(for: req)
        if let http = resp2 as? HTTPURLResponse, http.statusCode != 200 {
            throw SnapshotError.server("HTTP \(http.statusCode)")
        }
    }

    enum SnapshotError: Error { case server(String) }
}

// Convenience URL helper used above
private extension URL {
    func appending(_ name: String, value: String) -> URL {
        guard var comps = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
        var items = comps.queryItems ?? []
        items.append(.init(name: name, value: value))
        comps.queryItems = items
        return comps.url ?? self
    }
}
