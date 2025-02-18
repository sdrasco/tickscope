"""
data_handler.py

Module for storing and retrieving live trading data.
Currently, it stores the latest price updates in a deque.
"""

from collections import deque

# We'll store the latest 60 price updates (or adjust as needed)
price_history = deque(maxlen=60)

def update_price(price):
    """
    Add a new price to the price history.

    Parameters:
        price (float): The latest trade price.
    """
    price_history.append(price)
    # Optionally, log the update or perform additional processing here
    # For debugging:
    # print(f"Updated price history: {list(price_history)}")

def get_latest_price():
    """
    Retrieve the most recent price.

    Returns:
        float: The most recent price, or None if no price has been recorded.
    """
    if price_history:
        return price_history[-1]
    return None

def get_price_history():
    """
    Retrieve the entire price history.

    Returns:
        list: A list of stored price updates.
    """
    return list(price_history)