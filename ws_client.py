"""
ws_client.py

WebSocket client for fetching live price data from Polygon.io.
Supports dynamic ticker changes.
"""

import asyncio
import json
import websockets
from config import POLYGON_API_KEY, WS_ENDPOINT
from exchange_mapping import EXCHANGE_MAPPING
import charts  # Import charts to call update_price_chart()
from datetime import datetime

# Global variable to hold the current ticker symbol (without the "T." prefix).
current_ticker = "TSLA"
# Global variable for the active WebSocket connection.
ws_connection = None
# Global variable to hold the event loop used by the WebSocket client.
ws_loop = None

async def connect():
    global ws_connection, current_ticker, ws_loop
    ws_loop = asyncio.get_running_loop()  # Store the running event loop.
    async with websockets.connect(WS_ENDPOINT) as websocket:
        ws_connection = websocket
        # Step 1: Authenticate
        auth_message = {"action": "auth", "params": POLYGON_API_KEY}
        await websocket.send(json.dumps(auth_message))
        print("Sent authentication message.")
        
        # Wait for authentication response
        auth_response = await websocket.recv()
        print("Authentication response:", auth_response)
        
        # Step 2: Subscribe to the current ticker trade events channel
        subscribe_message = {"action": "subscribe", "params": f"T.{current_ticker}"}
        await websocket.send(json.dumps(subscribe_message))
        print(f"Subscribed to T.{current_ticker} channel.")
        
        # Step 3: Listen for incoming messages and process them
        while True:
            try:
                message = await websocket.recv()
                data = json.loads(message)
                if isinstance(data, list):
                    for item in data:
                        process_message(item)
                else:
                    process_message(data)
            except websockets.exceptions.ConnectionClosed as e:
                print("WebSocket connection closed:", e)
                break

def process_message(message):
    """
    Process an individual message from the WebSocket.
    For trade events (ev == "T"), update the live price using charts.update_price_chart().
    """
    if message.get("ev") == "T":  # Trade event
        # Extract and map exchange ID to a human-readable name.
        exchange_id = message.get("x")
        exchange_name = EXCHANGE_MAPPING.get(exchange_id, f"ID {exchange_id}")
        
        # Extract trade size, price, and timestamp.
        try:
            size = int(message.get("s", 0))
        except (ValueError, TypeError):
            size = 0
        try:
            price = float(message.get("p", 0.0))
        except (ValueError, TypeError):
            price = 0.0
        try:
            timestamp = int(message.get("t", 0))
        except (ValueError, TypeError):
            timestamp = 0
        
        # Convert timestamp from milliseconds to a datetime object.
        if timestamp:
            trade_time = datetime.fromtimestamp(timestamp / 1000.0)
        else:
            trade_time = datetime.now()
        
        # Update the live price in the Bokeh chart using price, trade_time, and trade size.
        charts.update_price_chart(price, trade_time, size)
    else:
        # Optionally handle non-trade events.
        pass

def change_ticker(new_ticker):
    """
    Change the current ticker subscription.
    If connected, unsubscribe from the current ticker and subscribe to the new one.
    
    Parameters:
        new_ticker (str): The new ticker symbol (e.g., "AAPL").
    """
    global ws_connection, current_ticker, ws_loop
    from asyncio import run_coroutine_threadsafe

    # If there's an active connection, send an unsubscribe for the current ticker.
    if ws_connection is not None and ws_loop is not None:
        unsubscribe_message = {"action": "unsubscribe", "params": f"T.{current_ticker}"}
        run_coroutine_threadsafe(ws_connection.send(json.dumps(unsubscribe_message)), ws_loop)
        print(f"Unsubscribed from T.{current_ticker}.")
    # Update the global ticker variable.
    current_ticker = new_ticker
    # If connected, subscribe to the new ticker.
    if ws_connection is not None and ws_loop is not None:
        subscribe_message = {"action": "subscribe", "params": f"T.{current_ticker}"}
        run_coroutine_threadsafe(ws_connection.send(json.dumps(subscribe_message)), ws_loop)
        print(f"Subscribed to T.{current_ticker} channel.")

def start_ws_client():
    asyncio.run(connect())

if __name__ == "__main__":
    start_ws_client()