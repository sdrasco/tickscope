"""
ws_client.py

WebSocket client fetching live price data from Polygon.io.
Simultaneously handles real-time trade events for a stock and an option ticker.
"""

import asyncio
import json
import websockets
from config import POLYGON_API_KEY
import charts
from datetime import datetime

# WebSocket endpoints
STOCK_WS_ENDPOINT = "wss://socket.polygon.io/stocks"
OPTION_WS_ENDPOINT = "wss://socket.polygon.io/options"

# Tickers for stock and option
stock_ticker = "TSLA"
option_ticker = "TSLA240315C00220000"

async def connect_stock():
    async with websockets.connect(STOCK_WS_ENDPOINT) as websocket:
        await websocket.send(json.dumps({"action": "auth", "params": POLYGON_API_KEY}))
        await websocket.recv()  # Wait for auth response

        subscribe_message = {"action": "subscribe", "params": f"T.{stock_ticker}"}
        await websocket.send(json.dumps(subscribe_message))

        while True:
            try:
                message = await websocket.recv()
                data = json.loads(message)
                for item in data:
                    process_stock_message(item)
            except websockets.exceptions.ConnectionClosed:
                break

async def connect_option():
    async with websockets.connect(OPTION_WS_ENDPOINT) as websocket:
        await websocket.send(json.dumps({"action": "auth", "params": POLYGON_API_KEY}))
        await websocket.recv()  # Wait for auth response

        subscribe_message = {"action": "subscribe", "params": f"T.O:{option_ticker}"}
        await websocket.send(json.dumps(subscribe_message))

        while True:
            try:
                message = await websocket.recv()
                data = json.loads(message)
                for item in data:
                    process_option_message(item)
            except websockets.exceptions.ConnectionClosed:
                break

def process_stock_message(message):
    if message.get("ev") == "T":
        price = float(message.get("p", 0.0))
        size = int(message.get("s", 0))
        timestamp = int(message.get("t", 0))
        trade_time = datetime.fromtimestamp(timestamp / 1000.0) if timestamp else datetime.now()

        if charts.bokeh_doc:
            charts.bokeh_doc.add_next_tick_callback(
                lambda: charts.update_price_doc(price, trade_time, size)
            )

def process_option_message(message):
    if message.get("ev") == "T":
        price = float(message.get("p", 0.0))
        size = int(message.get("s", 0))
        timestamp = int(message.get("t", 0))
        trade_time = datetime.fromtimestamp(timestamp / 1000.0) if timestamp else datetime.now()

        if charts.bokeh_doc_option:
            charts.bokeh_doc_option.add_next_tick_callback(
                lambda: charts.update_option_price_doc(price, trade_time, size)
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