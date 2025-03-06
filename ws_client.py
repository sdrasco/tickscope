"""
ws_client.py

WebSocket client fetching live stock and option data (trades and quotes) from Polygon.io.
Supports real-time charts for price, bid-ask spread, and volume heartbeat.
Enhanced with debugging logs.
"""

import asyncio
import json
import websockets
from config import POLYGON_API_KEY, STOCK_WS_ENDPOINT, OPTION_WS_ENDPOINT
import charts
from datetime import datetime

# Tickers for stock and option
stock_ticker = "TSLA"
option_ticker = "TSLA240315C00220000"

async def connect_stock():
    async with websockets.connect(STOCK_WS_ENDPOINT) as websocket:
        print(f"[Stock WS] Connecting to {STOCK_WS_ENDPOINT}")
        await websocket.send(json.dumps({"action": "auth", "params": POLYGON_API_KEY}))
        auth_response = await websocket.recv()
        print(f"[Stock WS] Auth response: {auth_response}")

        subscribe_message = {"action": "subscribe", "params": f"T.{stock_ticker},Q.{stock_ticker}"}
        await websocket.send(json.dumps(subscribe_message))
        print(f"[Stock WS] Subscribed to {stock_ticker} trades and quotes.")

        while True:
            try:
                message = await websocket.recv()
                data = json.loads(message)
                for item in data:
                    process_stock_message(item)
            except websockets.exceptions.ConnectionClosed:
                print("[Stock WS] Connection closed.")
                break

async def connect_option():
    async with websockets.connect(OPTION_WS_ENDPOINT) as websocket:
        print(f"[Option WS] Connecting to {OPTION_WS_ENDPOINT}")

        # Authenticate
        await websocket.send(json.dumps({"action": "auth", "params": POLYGON_API_KEY}))

        # Wait explicitly until auth_success message arrives
        while True:
            auth_response = await websocket.recv()
            print(f"[Option WS] Auth response: {auth_response}")
            auth_data = json.loads(auth_response)
            if any(item.get('status') == 'auth_success' for item in auth_data):
                print("[Option WS] Authenticated successfully.")
                break

        # Corrected subscription format here:
        subscribe_message = {
            "action": "subscribe",
            "params": f"T.O:{option_ticker},Q.O:{option_ticker}"
        }
        await websocket.send(json.dumps(subscribe_message))

        # Confirm subscription explicitly
        subscribe_response = await websocket.recv()
        print(f"[Option WS] Subscribe response: {subscribe_response}")

        # Handle incoming messages
        while True:
            try:
                message = await websocket.recv()
                data = json.loads(message)
                for item in data:
                    process_option_message(item)
            except websockets.exceptions.ConnectionClosed:
                print("[Option WS] Connection closed.")
                break

def process_stock_message(message):
    ev = message.get("ev")
    timestamp = int(message.get("t", 0))
    event_time = datetime.fromtimestamp(timestamp / 1000.0) if timestamp else datetime.now()

    if ev == "T":
        price = float(message.get("p", 0.0))
        size = int(message.get("s", 0))
        if charts.bokeh_docs['stock_price']:
            charts.bokeh_docs['stock_price'].add_next_tick_callback(
                lambda: charts.update_price_doc(price, event_time, size)
            )
        if charts.bokeh_docs['stock_volume']:
            charts.bokeh_docs['stock_volume'].add_next_tick_callback(
                lambda: charts.update_stock_volume_doc(size, event_time)
            )

    elif ev == "Q":
        bid = float(message.get("bp", 0.0))
        ask = float(message.get("ap", 0.0))
        if charts.bokeh_docs['stock_bidask']:
            charts.bokeh_docs['stock_bidask'].add_next_tick_callback(
                lambda: charts.update_stock_bidask_doc(bid, ask, event_time)
            )

def process_option_message(message):
    ev = message.get("ev")
    timestamp = int(message.get("t", 0))
    event_time = datetime.fromtimestamp(timestamp / 1000.0) if timestamp else datetime.now()

    if ev == "T":
        price = float(message.get("p", 0.0))
        size = int(message.get("s", 0))
        #print(f"[Option Trade] Price: {price}, Size: {size}, Time: {event_time}")
        if charts.bokeh_docs['option_price']:
            charts.bokeh_docs['option_price'].add_next_tick_callback(
                lambda: charts.update_option_price_doc(price, event_time, size)
            )
        if charts.bokeh_docs['option_volume']:
            charts.bokeh_docs['option_volume'].add_next_tick_callback(
                lambda: charts.update_option_volume_doc(size, event_time)
            )

    elif ev == "Q":
        bid = float(message.get("bp", 0.0))
        ask = float(message.get("ap", 0.0))
        if charts.bokeh_docs['option_bidask']:
            charts.bokeh_docs['option_bidask'].add_next_tick_callback(
                lambda: charts.update_option_bidask_doc(bid, ask, event_time)
            )

async def main_ws():
    await asyncio.gather(connect_stock(), connect_option())

def start_ws_client(stock, option):
    global stock_ticker, option_ticker
    stock_ticker = stock
    option_ticker = option
    asyncio.run(main_ws())

if __name__ == "__main__":
    start_ws_client(stock_ticker, option_ticker)