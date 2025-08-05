#pragma once

#include "option_pricing_input.h"

// Price an option using a Cox-Ross-Rubinstein binomial tree.
double binomial_price(const OptionPricingInput &input, int steps = 200);

// C-compatible wrapper for FFI usage.
extern "C" double binomial_price_ffi(const OptionPricingInput *input, int steps);

