#include "baw_pricer.h"

#include <cmath>
#include <algorithm>

namespace {
inline double norm_pdf(double x) {
    static const double inv_sqrt_2pi = 0.3989422804014327;
    return inv_sqrt_2pi * std::exp(-0.5 * x * x);
}
inline double norm_cdf(double x) {
    return 0.5 * std::erfc(-x / std::sqrt(2.0));
}

double european_price(const OptionPricingInput &in) {
    double S = in.spot, K = in.strike, T = in.timeToExpiry;
    double r = in.riskFreeRate, q = in.dividendYield, sigma = in.impliedVol;
    double sqrtT = std::sqrt(T);
    double d1 = (std::log(S / K) + (r - q + 0.5 * sigma * sigma) * T) / (sigma * sqrtT);
    double d2 = d1 - sigma * sqrtT;
    if (in.optionType == CALL) {
        return S * std::exp(-q * T) * norm_cdf(d1) - K * std::exp(-r * T) * norm_cdf(d2);
    } else {
        return K * std::exp(-r * T) * norm_cdf(-d2) - S * std::exp(-q * T) * norm_cdf(-d1);
    }
}
}

double baw_price(const OptionPricingInput &in) {
    double S = in.spot, K = in.strike, T = in.timeToExpiry;
    double r = in.riskFreeRate, q = in.dividendYield, sigma = in.impliedVol;
    bool call = (in.optionType == CALL);
    if (call && q <= 0.0) {
        return european_price(in); // no early exercise benefit
    }

    double sigma2 = sigma * sigma;
    double M = 2.0 * r / sigma2;
    double N = 2.0 * (r - q) / sigma2;
    double sqrtT = std::sqrt(T);

    if (call) {
        double q1 = (-(N - 1.0) + std::sqrt((N - 1.0)*(N - 1.0) + 4.0*M)) / 2.0;
        double K1 = K / (1.0 - 1.0/q1);
        double S_star = K + (K1 - K) * (1.0 - std::exp(-( (r - q) * T + 2.0 * sigma * sqrtT ) * (K / (K1 - K))));
        for (int i = 0; i < 5; ++i) {
            double d1 = (std::log(S_star / K) + (r - q + 0.5 * sigma2) * T) / (sigma * sqrtT);
            double Ce = S_star * std::exp(-q*T) * norm_cdf(d1) - K * std::exp(-r*T) * norm_cdf(d1 - sigma*sqrtT);
            double f = Ce + (1.0 - std::exp(-q*T) * norm_cdf(d1)) * (S_star / q1) - (S_star - K);
            double dCe_dS = std::exp(-q*T) * norm_cdf(d1);
            double fprime = dCe_dS + (1.0 - std::exp(-q*T) * norm_cdf(d1)) / q1 + std::exp(-q*T) * norm_pdf(d1) / (sigma * sqrtT * q1) - 1.0;
            double s_new = S_star - f / fprime;
            if (std::fabs(s_new - S_star) < 1e-6) break;
            S_star = s_new;
        }
        if (S >= S_star) return S - K;
        double d1 = (std::log(S_star / K) + (r - q + 0.5 * sigma2) * T) / (sigma * sqrtT);
        double A1 = (S_star / q1) * (1.0 - std::exp(-q*T) * norm_cdf(d1));
        return european_price(in) + A1 * std::pow(S / S_star, q1);
    } else {
        double q2 = (-(N - 1.0) - std::sqrt((N - 1.0)*(N - 1.0) + 4.0*M)) / 2.0;
        double K2 = K / (1.0 - 1.0/q2);
        double S_star = K + (K2 - K) * (1.0 - std::exp(-( (r - q) * T - 2.0 * sigma * sqrtT ) * (K / (K2 - K))));
        for (int i = 0; i < 5; ++i) {
            double d1 = (std::log(S_star / K) + (r - q + 0.5 * sigma2) * T) / (sigma * sqrtT);
            double Pe = K * std::exp(-r*T) * norm_cdf(-d1 + sigma*sqrtT) - S_star * std::exp(-q*T) * norm_cdf(-d1);
            double f = Pe - (1.0 - std::exp(-q*T) * norm_cdf(-d1)) * (S_star / q2) - (K - S_star);
            double dPe_dS = -std::exp(-q*T) * norm_cdf(-d1);
            double fprime = dPe_dS - (1.0 - std::exp(-q*T)*norm_cdf(-d1)) / q2 - std::exp(-q*T) * norm_pdf(d1) / (sigma * sqrtT * q2) + 1.0;
            double s_new = S_star - f / fprime;
            if (std::fabs(s_new - S_star) < 1e-6) break;
            S_star = s_new;
        }
        if (S <= S_star) return K - S;
        double d1 = (std::log(S_star / K) + (r - q + 0.5 * sigma2) * T) / (sigma * sqrtT);
        double A2 = -(S_star / q2) * (1.0 - std::exp(-q*T) * norm_cdf(-d1));
        return european_price(in) + A2 * std::pow(S / S_star, q2);
    }
}

extern "C" double baw_price_ffi(const OptionPricingInput *input) {
    return baw_price(*input);
}

