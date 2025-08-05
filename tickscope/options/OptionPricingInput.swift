import Foundation

/// Represents the core inputs required for option pricing models.
struct OptionPricingInput {
    /// Current underlying asset price
    var spot: Double
    /// Option strike price
    var strike: Double
    /// Time to expiry in years
    var timeToExpiry: Double
    /// Implied volatility expressed as a decimal (e.g. 0.2 for 20%)
    var impliedVol: Double
    /// Continuously compounded risk free rate
    var riskFreeRate: Double
    /// Call or put option type
    var optionType: OptionType
    /// Optional dividend yield of the underlying
    var dividendYield: Double?
}

/// Distinguishes between call and put options.
enum OptionType {
    case call
    case put
}
