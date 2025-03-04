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
def get_subscription_param(ticker, asset_type="stock"):
    """
    Returns the Polygon.io subscription parameter based on the asset type.

    Parameters:
        ticker (str): The ticker symbol (stock or option contract).
        asset_type (str): "stock" or "option".

    Returns:
        str: Subscription parameter string.
    """
    prefix = "T." if asset_type == "stock" else "T.O:"
    return f"{prefix}{ticker}"