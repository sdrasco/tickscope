"""
ws_client.py

WebSocket client for fetching live price data from Polygon.io.
"""

import asyncio
import json
import websockets
from config import POLYGON_API_KEY, WS_ENDPOINT
import data_handler
from exchange_mapping import EXCHANGE_MAPPING

async def connect():
    async with websockets.connect(WS_ENDPOINT) as websocket:
        # Step 1: Authenticate
        auth_message = {"action": "auth", "params": POLYGON_API_KEY}
        await websocket.send(json.dumps(auth_message))
        print("Sent authentication message.")
        
        # Wait for authentication response
        auth_response = await websocket.recv()
        print("Authentication response:", auth_response)
        
        # Step 2: Subscribe to the TSLA trade events channel
        subscribe_message = {"action": "subscribe", "params": "T.TSLA"}
        await websocket.send(json.dumps(subscribe_message))
        print("Subscribed to T.TSLA channel.")

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
    For trade events (ev == "T"), print:
      - Size as a 5-digit number with leading zeros
      - Price as a fixed-width value with two decimals
      - Timestamp as a 13-digit number (ms since epoch)
      - Exchange name
    And update the live price using the 'p' attribute.
    Only prints if trade size is >= 1000.
    """
    if message.get("ev") == "T":  # Trade event
        # Extract and map exchange ID to human-readable name
        exchange_id = message.get("x")
        exchange_name = EXCHANGE_MAPPING.get(exchange_id, f"ID {exchange_id}")
        
        # Extract trade size, price, and timestamp
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
        
        # Update the live price regardless of trade size
        data_handler.update_price(price)
        
        # Only print if trade size is 1000 or larger
        if size >= 1000:
            formatted_size = f"{size:05d}"          # 5-digit with leading zeros
            formatted_price = f"{price:8.2f}"         # Fixed width 8 characters, 2 decimals
            formatted_timestamp = f"{timestamp:013d}"  # 13-digit timestamp
            print(f"{formatted_size} | {formatted_price} | {formatted_timestamp} | {exchange_name}")
    else:
        # For non-trade events, we can choose to suppress output
        pass

def start_ws_client():
    asyncio.run(connect())

if __name__ == "__main__":
    start_ws_client()