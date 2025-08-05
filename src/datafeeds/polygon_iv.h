#pragma once

#include <string>
#include <unordered_map>
#include <optional>
#include <chrono>

// Fetches implied volatility for option contracts using the Polygon.io
// REST snapshot endpoint. Results are cached for a configurable
// duration to avoid hitting the API too frequently.
class PolygonIVFetcher {
public:
    // apiKey: Polygon.io API key.
    // cacheDuration: how long entries remain valid before refreshing.
    explicit PolygonIVFetcher(std::string apiKey,
                              std::chrono::seconds cacheDuration = std::chrono::seconds(60));

    // Retrieve the implied volatility for the given option contract symbol.
    // Returns std::nullopt on network or parse errors.
    std::optional<double> getIV(const std::string &optionSymbol);

    // Clears cached entries for contracts related to an underlying symbol.
    // Call this when external signals indicate a major market move.
    void notifyMajorMove(const std::string &underlyingSymbol);

private:
    struct CacheEntry {
        double iv{};
        std::chrono::steady_clock::time_point timestamp{};
    };

    std::optional<double> fetchFromPolygon(const std::string &optionSymbol);
    bool isStale(const CacheEntry &entry) const;

    std::string apiKey_;
    std::chrono::seconds cacheDuration_;
    std::unordered_map<std::string, CacheEntry> cache_;
};

