#pragma once

#include "option_pricing_input.h"

// Price an American option using the Barone-Adesi Whaley approximation.
double baw_price(const OptionPricingInput &input);

// C-compatible wrapper for FFI usage.
extern "C" double baw_price_ffi(const OptionPricingInput *input);

