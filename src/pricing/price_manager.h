#pragma once

#include <chrono>
#include "option_pricing_input.h"

// Manages option pricing recalculations based on market data changes.
class PriceManager {
public:
    explicit PriceManager(OptionPricingInput baseInput);

    // Update market data. Recalculates prices if thresholds are
    // exceeded and throttling allows.
    void update(double spot, double impliedVol, double timeToExpiry,
                double bid, double ask);

    double bawPrice() const { return bawPrice_; }
    double binomialPrice() const { return binomialPrice_; }
    double lastBid() const { return lastBid_; }
    double lastAsk() const { return lastAsk_; }
    const OptionPricingInput& input() const { return input_; }

private:
    bool needsRecalc(double spot, double iv, double time,
                     double bid, double ask) const;
    bool throttled() const;

    OptionPricingInput input_{};
    double lastBid_ = 0.0;
    double lastAsk_ = 0.0;
    double bawPrice_ = 0.0;
    double binomialPrice_ = 0.0;

    std::chrono::steady_clock::time_point lastUpdate_;
    std::chrono::seconds throttleInterval_ = std::chrono::seconds(3);

    static constexpr double spotThreshold_ = 0.001;      // 0.1%
    static constexpr double ivThreshold_ = 0.01;          // 1%
    static constexpr double bidAskThreshold_ = 0.001;    // 0.1%
    static constexpr double timeThreshold_ = 1.0 / 86400.0; // 1 second in years
};

