#pragma once

enum OptionType {
    CALL = 0,
    PUT = 1
};

struct OptionPricingInput {
    double spot;
    double strike;
    double timeToExpiry;
    double impliedVol;
    double riskFreeRate;
    OptionType optionType;
    double dividendYield; // set to 0 if not applicable
};

