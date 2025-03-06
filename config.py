"""
config.py

Configuration settings for Tickscope.
"""

import os

# Polygon.io API credentials (pulled from environment variable)
POLYGON_API_KEY = os.getenv("POLYGONIO_API_KEY")

# WebSocket endpoints
STOCK_WS_ENDPOINT = "wss://socket.polygon.io/stocks"
OPTION_WS_ENDPOINT = "wss://socket.polygon.io/options"

# Utility function to generate subscription parameters
def get_subscription_params(ticker, asset_type="stock", include_quotes=False):
    """
    Generates subscription parameters for Polygon.io based on asset type and data streams.

    Parameters:
        ticker (str): The ticker symbol (stock or option contract).
        asset_type (str): "stock" or "option".
        include_quotes (bool): Include quotes subscription.

    Returns:
        str: Subscription parameter string.
    """
    if asset_type == "stock":
        params = [f"T.{ticker}"]
        if include_quotes:
            params.append(f"Q.{ticker}")
    elif asset_type == "option":
        params = [f"T.O:{ticker}"]
        if include_quotes:
            params.append(f"Q.O:{ticker}")
    else:
        raise ValueError("asset_type must be 'stock' or 'option'.")

    return ",".join(params)