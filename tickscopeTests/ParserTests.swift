//
//  ParserTests.swift
//  tickscopeTests
//
//  Unit-tests using the Swift Testing framework (Swift 6).
//  They validate OCC / Polygon option-ticker strings with the same
//  rules used in the app’s TickerEntryView.
//

import Foundation
import Testing
@testable import tickscope

struct ParserTests {

    // MARK: - Helper ------------------------------------------------------

    /// Validates an OCC/Polygon option ticker string.
    /// Throws an `InputError` that matches the app’s own errors.
    private func validateOCC(_ s: String) throws {
        // OCC strings can be 16–21 chars: root 1-6 + YYMMDD + C/P + 8-digit strike
        guard (16...21).contains(s.count) else { throw InputError.length }

        let pattern = #"^([A-Z]{1,6})(\d{6})([CP])([A-Z0-9]{8})$"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            throw InputError.badFlag       // should never hit
        }
        guard
            let match = regex.firstMatch(in: s,
                                         range: NSRange(location: 0, length: s.utf16.count))
        else { throw InputError.badFlag }

        // Date validation (capture group 2)
        let dateRange = match.range(at: 2)
        guard let swiftRange = Range(dateRange, in: s) else { throw InputError.badDate }
        let dateStr = String(s[swiftRange])

        let df = DateFormatter(); df.dateFormat = "yyMMdd"; df.timeZone = .gmt
        guard df.date(from: dateStr) != nil else { throw InputError.badDate }

        // Strike numeric check (last 8 chars)
        let strikeStr = String(s.suffix(8))
        guard Int(strikeStr) != nil else { throw InputError.badStrike }
    }

    // MARK: - Tests -------------------------------------------------------

    @Test func validOCC() throws {
        let good = "TSLA250404P00200000"
        #expect( (try? validateOCC(good)) != nil )
    }

    @Test func weeklyOCC() throws {
        // Weeklies share the same format; root often ends with “W”
        let weekly = "SPXW250404P00500000"
        #expect( (try? validateOCC(weekly)) != nil )
    }

    @Test func badLength() throws {
        let bad = "TSLA"                      // too short
        #expect( catchInputError(bad) == .length )
    }

    @Test func invalidDate() throws {
        let bad = "TSLA990231P00200000"       // Feb 31 is invalid
        #expect( catchInputError(bad) == .badDate )
    }

    @Test func badStrike() throws {
        let bad = "TSLA250404P00ABC000"       // strike not numeric
        #expect( catchInputError(bad) == .badStrike )
    }

    @Test func badFlag() throws {
        let bad = "TSLA250404X00200000"       // X instead of C/P
        #expect( catchInputError(bad) == .badFlag )
    }

    // Helper to capture thrown `InputError`
    private func catchInputError(_ s: String) -> InputError? {
        do { try validateOCC(s); return nil }
        catch let err as InputError { return err }
        catch { return nil }
    }
}
