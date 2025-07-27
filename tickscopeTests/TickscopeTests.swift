import XCTest
@testable import tickscope

final class TickscopeTests: XCTestCase {
    func testFormatOptionDetailsValid() {
        let view = ContentView()
        let result = view.formatOptionDetails(from: "AAPL240621C00125000")
        XCTAssertEqual(result, "AAPL Call at $125 expiring 21 Jun 2024")
    }

    func testFormatOptionDetailsInvalid() {
        let view = ContentView()
        let input = "INVALID"
        XCTAssertEqual(view.formatOptionDetails(from: input), input)
    }

    func testExtractStockSymbol() {
        let view = ContentView()
        let ticker = "MSFT240621P00080000"
        XCTAssertEqual(view.extractStockSymbol(from: ticker), "MSFT")
    }

    func testOptionPriceRangeEdgeCases() {
        let manager = WebSocketManager()
        var view = OptionPriceChartView(webSocketManager: manager)
        // No data
        XCTAssertEqual(view.optionPriceRange(), 0...1)

        // Single price
        manager.optionTradePrices = [Trade(price: 5.0, timestamp: Date())]
        var range = view.optionPriceRange()
        XCTAssertEqual(range.lowerBound, 4.5, accuracy: 0.0001)
        XCTAssertEqual(range.upperBound, 5.5, accuracy: 0.0001)

        // Multiple prices
        manager.optionTradePrices = [Trade(price: 10.0, timestamp: Date()),
                                     Trade(price: 20.0, timestamp: Date())]
        range = view.optionPriceRange()
        XCTAssertEqual(range.lowerBound, 9.0, accuracy: 0.0001)
        XCTAssertEqual(range.upperBound, 21.0, accuracy: 0.0001)
    }

    func testOptionVolumeRangeEdgeCases() {
        let manager = WebSocketManager()
        var view = VolumeOptionChartView(webSocketManager: manager)
        // No data
        XCTAssertEqual(view.optionVolumeRange(), 0...10)

        // Max zero
        manager.optionVolumes = [VolumeData(volume: 0, timestamp: Date())]
        XCTAssertEqual(view.optionVolumeRange(), 0...10)

        // Positive volumes
        manager.optionVolumes = [VolumeData(volume: 10, timestamp: Date()),
                                 VolumeData(volume: 20, timestamp: Date())]
        XCTAssertEqual(view.optionVolumeRange(), 0...22)
    }
}
