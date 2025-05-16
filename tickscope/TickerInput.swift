//
//  TickerInput.swift
//  tickscope
//
//  Created by sdrasco on 16/05/2025.
//


//
//  TickerInput.swift
//  tickscope
//
//  Model types representing user-supplied option-ticker input and
//  associated validation errors.  Kept in a standalone file so they can be
//  shared by views, networking, and tests without importing ContractLookup.
//

import Foundation

/// Supported ways the UI can describe an option contract.
public enum TickerInput {
    /// Raw 21-character OCC / Polygon symbol, e.g. “TSLA250404P00200000”.
    case occ(String)
    /// Decomposed pieces; lets a form or picker build the contract without string wrangling.
    case components(root: String, expiry: Date, strike: Decimal, right: String)
}

/// Fine-grained parse/validation errors we can show to the user.
public enum InputError: LocalizedError, Equatable {
    case length, badDate, badStrike, badFlag

    public var errorDescription: String? {
        switch self {
        case .length:    return "Ticker must be 21 characters (e.g. TSLA250404P00200000)."
        case .badDate:   return "Expiry date looks invalid."
        case .badStrike: return "Strike field must be numeric."
        case .badFlag:   return "Ticker must end with C or P."
        }
    }
}
