"""
config.py

Configuration settings for Tickscope.
"""

import os

# Polygon.io API credentials and endpoints.
# The API key is pulled from the environment variable, or you can replace the default.
POLYGON_API_KEY = os.getenv("POLYGONIO_API_KEY")
WS_ENDPOINT = "wss://socket.polygon.io/stocks"

# Default subscription settings for live data.
DEFAULT_TICKER = "TSLA"
SUBSCRIPTION_CHANNEL = f"T.{DEFAULT_TICKER}"  # For trade events, e.g., "T.TSLA"

# Optional: Other configuration settings for future use
# For example, you might add thresholds, time intervals, etc.