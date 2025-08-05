#include "price_manager.h"
#include "baw_pricer.h"
#include "binomial_pricer.h"

#include <cmath>

PriceManager::PriceManager(OptionPricingInput baseInput)
    : input_(baseInput) {
    // Initial calculation so UI has values immediately.
    bawPrice_ = baw_price(input_);
    binomialPrice_ = binomial_price(input_);
    lastUpdate_ = std::chrono::steady_clock::now();
}

bool PriceManager::needsRecalc(double spot, double iv, double time,
                               double bid, double ask) const {
    if (input_.spot > 0.0 && std::fabs(spot - input_.spot) / input_.spot > spotThreshold_)
        return true;
    if (input_.impliedVol > 0.0 && std::fabs(iv - input_.impliedVol) / input_.impliedVol > ivThreshold_)
        return true;
    if (std::fabs(time - input_.timeToExpiry) > timeThreshold_)
        return true;
    if (lastBid_ > 0.0 && std::fabs(bid - lastBid_) / lastBid_ > bidAskThreshold_)
        return true;
    if (lastAsk_ > 0.0 && std::fabs(ask - lastAsk_) / lastAsk_ > bidAskThreshold_)
        return true;
    return false;
}

bool PriceManager::throttled() const {
    return std::chrono::steady_clock::now() - lastUpdate_ < throttleInterval_;
}

void PriceManager::update(double spot, double iv, double time,
                          double bid, double ask) {
    if (!needsRecalc(spot, iv, time, bid, ask))
        return;
    if (throttled())
        return;

    input_.spot = spot;
    input_.impliedVol = iv;
    input_.timeToExpiry = time;
    bawPrice_ = baw_price(input_);
    binomialPrice_ = binomial_price(input_);
    lastBid_ = bid;
    lastAsk_ = ask;
    lastUpdate_ = std::chrono::steady_clock::now();
}

