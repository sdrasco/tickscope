//
//  ContractLookup.swift
//  tickscope
//

import Foundation

// MARK: – TLS delegate that trusts the Gateway’s self-signed certificate
private final class LocalhostTLSDelegate: NSObject, URLSessionDelegate {
    func urlSession(_ session: URLSession,
                    didReceive challenge: URLAuthenticationChallenge,
                    completionHandler: @escaping (URLSession.AuthChallengeDisposition, URLCredential?) -> Void) {
        completionHandler(.useCredential,
                          URLCredential(trust: challenge.protectionSpace.serverTrust!))
    }
}

/// Re-usable session that skips TLS checks for https://127.0.0.1:PORT
private let insecureLocalSession: URLSession = {
    URLSession(configuration: .default,
               delegate: LocalhostTLSDelegate(),
               delegateQueue: nil)
}()

// ======================================================================
// MARK: – ContractLookup
// ======================================================================

enum ContractLookup {

    private static let cacheQueue = DispatchQueue(label: "ContractLookup.cache")
    private static var cache: [String: Int] = [:]      // key = "TYPE|TICKER" → conId

    // ------------------------------------------------------------------
    // MARK: Public look-ups
    // ------------------------------------------------------------------

    /// Stock symbol → conId.  Uses the documented *POST* variant of
    /// `/iserver/secdef/search` (sending `{"symbol": "BA"}`), then picks the
    /// first result whose `sections` include both STK and OPT.
    static func stockConId(for symbol: String) async throws -> Int {
        if let cached = cachedId(for: symbol, type: "STK") { return cached }
        print("🔎 stockConId lookup for", symbol)

        let url = Config.restBaseURL.appendingPathComponent("/iserver/secdef/search")
        var req = URLRequest(url: url)
        req.httpMethod = "POST"
        req.setValue("application/json", forHTTPHeaderField: "Content-Type")
        req.httpBody = try JSONSerialization.data(withJSONObject: ["symbol": symbol])
        req.timeoutInterval = 8

        let (data, _) = try await insecureLocalSession.data(for: req)

        // Debug: see the raw search payload once
        if let s = String(data: data, encoding: .utf8) {
            print("🔎 search raw JSON:", s)
        }

        guard
            let results = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        else { throw LookupError.notFound }

        let preferred = results.first(where: { obj in
            guard let secs = obj["sections"] as? [[String: Any]] else { return false }
            let types = secs.compactMap { $0["secType"] as? String }
            return types.contains("STK") && types.contains("OPT")
        })

        guard let stock = preferred ?? results.first else {
            throw LookupError.notFound
        }

        // conid may arrive as String or Int
        let id: Int
        if let n = stock["conid"] as? Int {
            id = n
        } else if let s = stock["conid"] as? String, let n = Int(s) {
            id = n
        } else {
            throw LookupError.notFound
        }

        cache(symbol, type: "STK", id: id)
        print("✅ stockConId =", id)
        return id
    }

    /// OCC option ticker (e.g. “BA250620P00180000”) → concrete option conId.
    /// Flow:
    ///   1. Underlying conid via `/iserver/secdef/search`
    ///   2. Specific contract via `/iserver/secdef/info`
    ///   3. Pick row whose `maturityDate` matches the OCC date.
    static func optionConId(for occ: String) async throws -> Int {
        if let cached = cachedId(for: occ, type: "OPT") { return cached }
        print("🚀 optionConId entered for", occ)

        // 1️⃣ Parse OCC
        guard let p = parseOCC(occ) else { throw LookupError.badTicker }
        print("✅ OCC parsed:", p)

        // 2️⃣ Underlying conid
        let underlyingID = try await stockConId(for: p.symbol)
        print("📦 Underlying conid =", underlyingID)

        // 3️⃣ Convert expiry → month code “MMMyy” (20250620 → JUN25)
        let inFmt = DateFormatter();  inFmt.dateFormat  = "yyyyMMdd"
        let outFmt = DateFormatter(); outFmt.dateFormat = "MMMyy"
        outFmt.locale = Locale(identifier: "en_US_POSIX")
        guard let d = inFmt.date(from: p.expiry) else { throw LookupError.badTicker }
        let monthCode = outFmt.string(from: d).uppercased()          // JUN25

        // 4️⃣ Plain-dollar strike (00180000 → 180 or 182.5)
        let dollars = (Double(p.strike) ?? 0) / 1000.0
        let plainStrike = dollars.truncatingRemainder(dividingBy: 1) == 0
            ? String(Int(dollars)) : String(dollars)

        // 5️⃣ /iserver/secdef/info
        var url = Config.restBaseURL.appendingPathComponent("/iserver/secdef/info")
        url = url
            .appending("conid",    value: String(underlyingID))
            .appending("sectype",  value: "OPT")
            .appending("month",    value: monthCode)     // JUN25
            .appending("right",    value: p.right)       // C or P
            .appending("strike",   value: plainStrike)   // 180
            .appending("exchange", value: "SMART")

        // Debug: see exactly what we ask the Gateway
        print("⛳️ SECDEF‑INFO URL:", url.absoluteString)

        var req = URLRequest(url: url); req.timeoutInterval = 8
        let (data, _) = try await insecureLocalSession.data(for: req)

        // Debug: raw JSON the Gateway returned
        print("⛳️ RAW JSON:", String(data: data, encoding: .utf8) ?? "<nil>")

        // 6️⃣ Match by maturityDate
        let rows = (try? JSONSerialization.jsonObject(with: data)) as? [[String: Any]] ?? []

        // Prefer exact maturityDate match; otherwise fall back to first row.
        let match = rows.first(where: { ($0["maturityDate"] as? String) == p.expiry }) ?? rows.first

        guard let contract = match else { throw LookupError.notFound }

        let optID: Int
        if let n = contract["conid"] as? Int {
            optID = n
        } else if let s = contract["conid"] as? String, let n = Int(s) {
            optID = n
        } else {
            throw LookupError.notFound
        }

        cache(occ, type: "OPT", id: optID)
        return optID
    }

    // ------------------------------------------------------------------
    // MARK: Internals
    // ------------------------------------------------------------------

    private static func firstConId(from url: URL) async throws -> Int {
        var req = URLRequest(url: url); req.timeoutInterval = 8
        let (data, _) = try await insecureLocalSession.data(for: req)

        guard
            let arr   = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
            let first = arr.first,
            let id    = first["conid"] as? Int
        else { throw LookupError.notFound }

        return id
    }

    /// Parse OCC ticker → (symbol, expiry YYYYMMDD, right, strike 8-digit)
    private static func parseOCC(_ occ: String) -> (symbol: String,
                                                    expiry: String,
                                                    right: String,
                                                    strike: String)? {
        let pattern = #"^([A-Z]{1,6})(\d{6})([CP])(\d{8})$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return nil }
        let ns = NSRange(occ.startIndex..<occ.endIndex, in: occ)

        guard let m = regex.firstMatch(in: occ, range: ns),
              m.numberOfRanges == 5,
              let r1 = Range(m.range(at: 1), in: occ),
              let r2 = Range(m.range(at: 2), in: occ),
              let r3 = Range(m.range(at: 3), in: occ),
              let r4 = Range(m.range(at: 4), in: occ) else { return nil }

        let symbol = String(occ[r1])
        let expiry = "20" + String(occ[r2])   // YYMMDD → YYYYMMDD
        let right  = String(occ[r3])          // C / P
        let strike = String(occ[r4])          // 8 digits
        return (symbol, expiry, right, strike)
    }

    private static func cachedId(for key: String, type: String) -> Int? {
        cacheQueue.sync { cache["\(type)|\(key)"] }
    }
    private static func cache(_ key: String, type: String, id: Int) {
        cacheQueue.sync { cache["\(type)|\(key)"] = id }
    }

    enum LookupError: Error { case badTicker, notFound }
}   // ← end of enum ContractLookup

// ----------------------------------------------------------------------
// MARK: – URL helper
// ----------------------------------------------------------------------
private extension URL {
    func appending(_ name: String, value: String) -> URL {
        guard var comps = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
        var items = comps.queryItems ?? []
        items.append(.init(name: name, value: value))
        comps.queryItems = items
        return comps.url ?? self
    }
}
