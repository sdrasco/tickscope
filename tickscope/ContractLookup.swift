//
//  ContractLookup.swift
//  tickscope
//
//  Created by sdrasco on 09/05/2025.
//


//
//  ContractLookup.swift
//  tickscope
//

import Foundation

/// Thin wrapper around the Client-Portal REST API that translates symbols ⇢ conId.
/// Keeps a simple in-memory cache so repeat lookups are instant.
enum ContractLookup {

    private static let cacheQueue = DispatchQueue(label: "ContractLookup.cache")
    private static var cache: [String: Int] = [:]          // key = canonical ticker|type

    /// Resolves a **stock** symbol like “TSLA” → 648703 (example conId).
    static func stockConId(for symbol: String) async throws -> Int {
        if let cached = cachedId(for: symbol, type: "STK") { return cached }

        let url = Config.restBaseURL
            .appendingPathComponent("/iserver/secdef/search")
            .appending("symbol", value: symbol)
            .appending("secType", value: "STK")

        let id = try await firstConId(from: url)
        cache(symbol, type: "STK", id: id)
        return id
    }

    /// Resolves an OCC option string (e.g. “NVDA250328C00131000”) to a conId.
    static func optionConId(for occ: String) async throws -> Int {
        if let cached = cachedId(for: occ, type: "OPT") { return cached }

        // Parse OCC ticker into pieces IBKR expects
        guard let parts = parseOCC(occ) else {
            throw LookupError.badTicker
        }

        var url = Config.restBaseURL.appendingPathComponent("/iserver/secdef/search")
        url = url
            .appending("symbol",  value: parts.symbol)
            .appending("secType", value: "OPT")
            .appending("strike",  value: parts.strike)
            .appending("right",   value: parts.right)
            .appending("expiry",  value: parts.expiry)

        let id = try await firstConId(from: url)
        cache(occ, type: "OPT", id: id)
        return id
    }

    // MARK: – Internals ------------------------------------------------------

    private static func firstConId(from url: URL) async throws -> Int {
        var request = URLRequest(url: url)
        request.timeoutInterval = 8
        let (data, _) = try await URLSession.shared.data(for: request)

        let objects = try JSONSerialization.jsonObject(with: data) as? [[String: Any]]
        guard
            let first = objects?.first,
            let id = first["conid"] as? Int
        else { throw LookupError.notFound }

        return id
    }

    private static func parseOCC(_ occ: String) -> (symbol: String,
                                                    expiry: String,
                                                    right: String,
                                                    strike: String)? {
        // OCC format: SYMBOL(1-6) YYMMDD C/P STRIKE(8)
        let pattern = #"^([A-Z]{1,6})(\d{6})([CP])(\d{8})$"#
        guard
            let r = occ.firstMatch(of: pattern),
            let symbol  = r[1], let date = r[2],
            let right   = r[3], let strike = r[4]
        else { return nil }

        // IBKR expects full-year “YYYYMMDD”
        let expiry = "20" + date
        return (String(symbol), expiry, String(right), String(strike))
    }

    private static func cachedId(for key: String, type: String) -> Int? {
        cacheQueue.sync { cache["\(type)|\(key)"] }
    }
    private static func cache(_ key: String, type: String, id: Int) {
        cacheQueue.sync { cache["\(type)|\(key)"] = id }
    }

    enum LookupError: Error {
        case badTicker, notFound
    }
}

private extension URL {
    func appending(_ name: String, value: String) -> URL {
        guard var comps = URLComponents(url: self, resolvingAgainstBaseURL: false) else { return self }
        var items = comps.queryItems ?? []
        items.append(.init(name: name, value: value))
        comps.queryItems = items
        return comps.url ?? self
    }
}

private extension String {
    /// Swift 5.9 trick: returns substrings for regex capture groups 1…n
    func firstMatch(of pattern: String) -> [Substring?]? {
        guard let r = try? Regex(pattern) else { return nil }
        return firstMatch(of: r)?.output
    }
}
