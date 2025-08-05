#include "binomial_pricer.h"

#include <vector>
#include <cmath>

namespace {
inline double max(double a, double b) { return a > b ? a : b; }
}

double binomial_price(const OptionPricingInput &input, int steps) {
    if (steps < 1) steps = 1;
    double dt = input.timeToExpiry / steps;
    double u = std::exp(input.impliedVol * std::sqrt(dt));
    double d = 1.0 / u;
    double disc = std::exp((input.riskFreeRate - input.dividendYield) * dt);
    double p = (disc - d) / (u - d);
    double discount = std::exp(-input.riskFreeRate * dt);

    std::vector<double> prices(steps + 1);
    for (int i = 0; i <= steps; ++i) {
        double s = input.spot * std::pow(u, steps - i) * std::pow(d, i);
        if (input.optionType == CALL) {
            prices[i] = max(s - input.strike, 0.0);
        } else {
            prices[i] = max(input.strike - s, 0.0);
        }
    }

    for (int step = steps - 1; step >= 0; --step) {
        for (int i = 0; i <= step; ++i) {
            double continuation = (p * prices[i] + (1.0 - p) * prices[i + 1]) * discount;
            double s = input.spot * std::pow(u, step - i) * std::pow(d, i);
            double intrinsic;
            if (input.optionType == CALL) {
                intrinsic = max(s - input.strike, 0.0);
            } else {
                intrinsic = max(input.strike - s, 0.0);
            }
            prices[i] = max(continuation, intrinsic);
        }
    }
    return prices[0];
}

extern "C" double binomial_price_ffi(const OptionPricingInput *input, int steps) {
    return binomial_price(*input, steps);
}

