"""
app.py

Main entry point for Tickscope.
Initializes Dash app with embedded Bokeh charts for stock and option prices,
bid-ask spread, and volume heartbeat charts, starts WebSocket clients and Bokeh server.
"""

import sys
import threading
from dash import Dash, html
import ws_client
from flask import Response
from tornado.ioloop import IOLoop
from bokeh.server.server import Server
from bokeh.embed import server_document
from charts import (
    modify_price_doc,
    modify_option_price_doc,
    modify_stock_bidask_doc,
    modify_option_bidask_doc,
    modify_stock_volume_doc,
    modify_option_volume_doc
)
from utils import extract_stock_from_option, parse_ticker
from datetime import datetime

# Determine tickers from command-line argument; provide default
DEFAULT_OPTION_TICKER = "TSLA240315C00220000"

option_ticker = sys.argv[1].upper() if len(sys.argv) > 1 else DEFAULT_OPTION_TICKER
stock_ticker = extract_stock_from_option(option_ticker)

# Parse option details for human-readable title
option_details = parse_ticker(option_ticker)
option_type = option_details["option_type"].capitalize()
strike_price = option_details["strike_price"]
exp_date = datetime.strptime(option_details["expiration"], "%y%m%d").strftime("%d %B %Y")

# Update ws_client tickers
ws_client.stock_ticker = stock_ticker
ws_client.option_ticker = option_ticker

# Initialize Dash app and expose Flask server
app = Dash(__name__)
server = app.server

# Start Bokeh server with all charts in a background thread
def bk_worker():
    io_loop = IOLoop()
    bokeh_server = Server(
        {
            '/bokeh/stock_price': modify_price_doc,
            '/bokeh/option_price': modify_option_price_doc,
            '/bokeh/stock_bidask': modify_stock_bidask_doc,
            '/bokeh/option_bidask': modify_option_bidask_doc,
            '/bokeh/stock_volume': modify_stock_volume_doc,
            '/bokeh/option_volume': modify_option_volume_doc,
        },
        io_loop=io_loop,
        allow_websocket_origin=["localhost:8050", "localhost:5006"],
        port=5006,
        websocket_max_message_size=10000000,
        show=False,
        dev=False
    )
    bokeh_server.start()
    io_loop.start()

threading.Thread(target=bk_worker, daemon=True).start()

# Flask route to serve embedded Bokeh apps via iframe
@server.route('/bokeh/<chart_id>')
def bkapp_page(chart_id):
    script = server_document(f"http://localhost:5006/bokeh/{chart_id}")
    html_page = f"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <title>Tickscope Chart - {chart_id}</title>
        <style>
            html, body {{ margin:0; padding:0; overflow:hidden; }}
        </style>
    </head>
    <body>
        {script}
    </body>
    </html>
    """
    return Response(html_page, mimetype='text/html')

# Dash layout embedding all Bokeh charts side-by-side
def generate_layout():
    return html.Div([
        html.H1(
            f"Tickscope: {stock_ticker} {option_type} at {strike_price:g} expiring {exp_date}",
            style={"text-align": "center", "font-family": "Helvetica, sans-serif"}
        ),

        html.Div([
            html.Div([
                html.Iframe(src="/bokeh/stock_price", style={"width": "100%", "height": "250px", "border": "none"}),
                html.Iframe(src="/bokeh/stock_bidask", style={"width": "100%", "height": "250px", "border": "none"}),
                html.Iframe(src="/bokeh/stock_volume", style={"width": "100%", "height": "250px", "border": "none"}),
            ], style={"width": "50%", "padding": "5px", "display": "inline-block"}),
            
            html.Div([
                html.Iframe(src="/bokeh/option_price", style={"width": "100%", "height": "250px", "border": "none"}),
                html.Iframe(src="/bokeh/option_bidask", style={"width": "100%", "height": "250px", "border": "none"}),
                html.Iframe(src="/bokeh/option_volume", style={"width": "100%", "height": "250px", "border": "none"}),
            ], style={"width": "50%", "display": "inline-block", "padding": "5px"}),
        ], style={"display": "flex", "justify-content": "space-between"})
    ])

app.layout = generate_layout()

# Start WebSocket clients for real-time data
def start_websocket_clients():
    ws_client.start_ws_client(stock_ticker, option_ticker)

if __name__ == '__main__':
    ws_thread = threading.Thread(target=start_websocket_clients, daemon=True)
    ws_thread.start()

    # Run Dash server
    app.run_server(debug=False, use_reloader=False)