"""
ws_client.py

WebSocket client for fetching live price data from Polygon.io.
Fetches real-time trade events for a single, command-line defined ticker.
"""

import asyncio
import json
import websockets
from config import POLYGON_API_KEY, WS_ENDPOINT
from exchange_mapping import EXCHANGE_MAPPING
import charts  # Using the OOP-style charts module.
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
        
        # Wait for authentication response.
        auth_response = await websocket.recv()
        print("Authentication response:", auth_response)
        
        # Step 2: Subscribe to the current ticker's trade events channel.
        subscribe_message = {"action": "subscribe", "params": f"T.{current_ticker}"}
        await websocket.send(json.dumps(subscribe_message))
        print(f"Subscribed to T.{current_ticker} channel.")
        
        # Step 3: Listen for incoming messages and process them.
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
    For trade events (ev == "T"), update the live price using charts.update_price_doc().
    """
    if message.get("ev") == "T":  # Trade event
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
        
        # Update the live price chart.
        if charts.bokeh_doc is not None:
            charts.bokeh_doc.add_next_tick_callback(
                lambda: charts.update_price_doc(price, trade_time, size)
            )
        #else:
            # Bokeh document is not yet available; update is skipped or could be queued.
            #print("Bokeh document not yet available; update skipped.")
    else:
        # Optionally handle non-trade events.
        pass

def start_ws_client():
    asyncio.run(connect())

if __name__ == "__main__":
    start_ws_client()