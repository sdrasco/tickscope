//
//  ContractLookup.swift
//  tickscope
//

import Foundation

// MARK: – User‑input model
// TickerInput and InputError enums now live in TickerInput.swift

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

        let (data, resp) = try await insecureLocalSession.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = obj["error"] as? String {
                throw LookupError.server(msg)
            }
            throw LookupError.server("HTTP \(http.statusCode)")
        }

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
    static func optionConId(forOCC occ: String) async throws -> Int {
        if let cached = cachedId(for: occ, type: "OPT") { return cached }
        print("🚀 optionConId entered for", occ)

        // 1️⃣ Parse OCC
        let p = try parseOCC(occ)
        print("✅ OCC parsed:", p)

        // 2️⃣ Underlying conid
        let underlyingID = try await stockConId(for: p.symbol)
        print("📦 Underlying conid =", underlyingID)

        // 3️⃣ Convert expiry → month code “MMMyy” (20250620 → JUN25)
        let inFmt = DateFormatter();  inFmt.dateFormat  = "yyyyMMdd"
        let outFmt = DateFormatter(); outFmt.dateFormat = "MMMyy"
        outFmt.locale = Locale(identifier: "en_US_POSIX")
        guard let d = inFmt.date(from: p.expiry) else { throw LookupError.notFound }
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
        let (data, resp) = try await insecureLocalSession.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = obj["error"] as? String {
                throw LookupError.server(msg)
            }
            throw LookupError.server("HTTP \(http.statusCode)")
        }

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

    /// Universal resolver that takes either a raw OCC string or decomposed parts.
    static func resolve(_ input: TickerInput) async throws -> Int {
        switch input {
        case .occ(let raw):
            return try await optionConId(forOCC: raw)
        case .components(let root, let expiry, let strike, let right):
            // Render components → OCC 21‑char symbol
            let root6 = root.padding(toLength: 6, withPad: " ", startingAt: 0).uppercased()
            let dateFmt = DateFormatter(); dateFmt.dateFormat = "yyMMdd"; dateFmt.timeZone = .gmt
            let yyMMdd = dateFmt.string(from: expiry)
            let strikeInt = Int((NSDecimalNumber(decimal: strike).doubleValue * 1000).rounded())
            let strikeField = String(format: "%08d", strikeInt)
            let occ = "\(root6)\(yyMMdd)\(right.uppercased())\(strikeField)"
            return try await optionConId(forOCC: occ)
        }
    }

    // ------------------------------------------------------------------
    // MARK: Internals
    // ------------------------------------------------------------------

    private static func firstConId(from url: URL) async throws -> Int {
        var req = URLRequest(url: url); req.timeoutInterval = 8
        let (data, resp) = try await insecureLocalSession.data(for: req)
        if let http = resp as? HTTPURLResponse, http.statusCode != 200 {
            if let obj = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
               let msg = obj["error"] as? String {
                throw LookupError.server(msg)
            }
            throw LookupError.server("HTTP \(http.statusCode)")
        }

        guard
            let arr   = try JSONSerialization.jsonObject(with: data) as? [[String: Any]],
            let first = arr.first,
            let id    = first["conid"] as? Int
        else { throw LookupError.notFound }

        return id
    }

    /// Parse OCC ticker → (symbol, expiry YYYYMMDD, right, strike 8‑digit)
    private static func parseOCC(_ occ: String) throws -> (symbol: String,
                                                           expiry: String,
                                                           right: String,
                                                           strike: String) {
        // OCC strings are 16‑21 chars (root 1‑6 + YYMMDD + C/P + 8‑digit strike)
        guard (16...21).contains(occ.count) else { throw InputError.length }

        // Accept any alphanumerics in the 8‑char strike field so
        // `Int(strike)` can later throw `.badStrike` if non‑numeric.
        let pattern = #"^([A-Z]{1,6})(\d{6})([CP])([A-Z0-9]{8})$"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let m = regex.firstMatch(in: occ, range: NSRange(location: 0, length: occ.utf16.count)),
              m.numberOfRanges == 5
        else { throw InputError.badFlag }

        func slice(_ idx: Int) -> String {
            let range = m.range(at: idx)
            let start = occ.index(occ.startIndex, offsetBy: range.location)
            let end   = occ.index(start, offsetBy: range.length)
            return String(occ[start..<end])
        }

        let symbol = slice(1).trimmingCharacters(in: .whitespaces)
        let yyMMdd = slice(2)
        let right  = slice(3)
        let strike = slice(4)

        // Validate YYMMDD
        let inFmt = DateFormatter(); inFmt.dateFormat = "yyMMdd"; inFmt.timeZone = .gmt
        guard let d = inFmt.date(from: yyMMdd) else { throw InputError.badDate }

        // Re‑emit expiry as YYYYMMDD
        let outFmt = DateFormatter(); outFmt.dateFormat = "yyyyMMdd"; outFmt.timeZone = .gmt
        let expiry = outFmt.string(from: d)

        // Strike numeric sanity check
        guard Int(strike) != nil else { throw InputError.badStrike }

        return (symbol, expiry, right, strike)
    }

    private static func cachedId(for key: String, type: String) -> Int? {
        cacheQueue.sync { cache["\(type)|\(key)"] }
    }
    private static func cache(_ key: String, type: String, id: Int) {
        cacheQueue.sync { cache["\(type)|\(key)"] = id }
    }

    enum LookupError: Error { case notFound, server(String) }
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
