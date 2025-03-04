"""
app.py

Main entry point for Tickscope.
Initializes Dash app with embedded Bokeh charts for stock and option prices,
starts WebSocket clients and Bokeh server.
"""

import sys
import threading
from dash import Dash, html
import ws_client
from flask import Response
from tornado.ioloop import IOLoop
from bokeh.server.server import Server
from bokeh.embed import server_document
from charts import modify_price_doc, modify_option_price_doc

# Get tickers from command-line arguments; defaults provided
default_stock_ticker = "TSLA"
default_option_ticker = "TSLA240315C00220000"

stock_ticker = sys.argv[1].upper() if len(sys.argv) > 1 else default_stock_ticker
option_ticker = sys.argv[2].upper() if len(sys.argv) > 2 else default_option_ticker

# Update ws_client tickers
ws_client.stock_ticker = stock_ticker
ws_client.option_ticker = option_ticker

# Initialize Dash app and expose Flask server
app = Dash(__name__)
server = app.server

# Start Bokeh server in a background thread with two chart endpoints
def bk_worker():
    io_loop = IOLoop()
    bokeh_server = Server(
        {
            '/bokeh/stock_price': modify_price_doc,
            '/bokeh/option_price': modify_option_price_doc,
        },
        io_loop=io_loop,
        allow_websocket_origin=["localhost:8050", "localhost:5006"],
        port=5006
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
        <title>TickScope Chart - {chart_id}</title>
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

# Dash layout with side-by-side embedded Bokeh charts
def generate_layout():
    return html.Div([
        html.H1(
            f"TickScope: {stock_ticker} & {option_ticker}",
            style={"text-align": "center", "font-family": "Helvetica, sans-serif"}
        ),
        html.Div([
            html.Div([
                html.H3(f"Stock: {stock_ticker}", style={"text-align": "center"}),
                html.Iframe(
                    src="/bokeh/stock_price",
                    style={
                        "width": "100%",
                        "height": "300px",
                        "border": "none",
                        "box-sizing": "border-box",
                        "overflow": "hidden"
                    }
                ),
            ], style={"width": "50%", "display": "inline-block", "padding": "5px"}),

            html.Div([
                html.H3(f"Option: {option_ticker}", style={"text-align": "center"}),
                html.Iframe(
                    src="/bokeh/option_price",
                    style={
                        "width": "100%",
                        "height": "300px",
                        "border": "none",
                        "box-sizing": "border-box",
                        "overflow": "hidden"
                    }
                ),
            ], style={"width": "50%", "display": "inline-block", "padding": "5px"}),
        ], style={"display": "flex", "justify-content": "space-between"})
    ], style={"width": "100%", "box-sizing": "border-box"})

app.layout = generate_layout()

# Start WebSocket client for real-time data (stock & option)
def start_websocket_clients():
    ws_client.start_ws_client(stock_ticker, option_ticker)

if __name__ == '__main__':
    ws_thread = threading.Thread(target=start_websocket_clients, daemon=True)
    ws_thread.start()

    # Run Dash server
    app.run_server(debug=True, use_reloader=False)