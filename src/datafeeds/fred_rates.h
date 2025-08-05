#pragma once

#include <string>
#include <optional>
#include <chrono>

// Loads Treasury yields from the Federal Reserve Economic Data (FRED)
// API. Rates for the 1M, 3M and 6M tenors are fetched at most once per
// day and cached in memory. The helper get_rate_for_expiry will return
// the appropriate rate based on the number of days until expiry.
class FredRateLoader {
public:
    explicit FredRateLoader(std::string apiKey);

    // Returns the annualized yield (as a decimal, e.g. 0.05 for 5%)
    // corresponding to the given days to expiry. Returns std::nullopt
    // if rates could not be retrieved.
    std::optional<double> get_rate_for_expiry(int days_to_expiry);

private:
    struct RateData {
        double rate1M{0.0};
        double rate3M{0.0};
        double rate6M{0.0};
        std::chrono::system_clock::time_point fetched{};
        bool valid{false};
    };

    bool isStale() const;
    bool fetchRates();
    std::optional<double> fetchRate(const std::string &seriesId);

    std::string apiKey_;
    RateData data_;
};

