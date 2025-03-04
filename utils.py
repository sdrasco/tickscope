"""
utils.py

Utility functions for Tickscope.
Includes parsing functionality for tickers (stocks and options).
"""

import re

OPTION_TICKER_PATTERN = re.compile(r"""
    ^([A-Z]{1,6})          # underlying ticker (1-6 uppercase letters)
    (\d{6})                # expiration date (YYMMDD)
    ([CP])                 # option type: Call or Put
    (\d{8})$               # strike price, 8 digits (divide by 1000 for actual price)
""", re.VERBOSE)

def parse_ticker(ticker):
    """
    Parses a ticker symbol to determine if it's an option or stock.
    Returns a dictionary with parsed details.
    """
    match = OPTION_TICKER_PATTERN.match(ticker)
    if match:
        underlying, exp_date, opt_type, strike_price = match.groups()
        return {
            "type": "option",
            "underlying": underlying,
            "expiration": exp_date,   # YYMMDD format
            "option_type": "call" if opt_type == "C" else "put",
            "strike_price": int(strike_price) / 1000
        }
    else:
        return {
            "type": "stock",
            "symbol": ticker
        }