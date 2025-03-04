"""
app.py

Main entry point for Tickscope.
Initializes Dash app with Bokeh charts embedded via iframe,
starts WebSocket client and Bokeh server.
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
    modify_speed_doc,
    modify_acceleration_doc,
    modify_price_pdf_doc,
    modify_volume_pdf_doc,
    modify_exchange_hist_doc
)

# Determine ticker from command-line argument; default to TSLA.
default_ticker = "TSLA"
ticker = sys.argv[1].upper() if len(sys.argv) > 1 else default_ticker

# Update the ws_client's current ticker.
ws_client.current_ticker = ticker

# Initialize Dash app and expose Flask server.
app = Dash(__name__)
server = app.server

# Start the Bokeh server in a background thread.
def bk_worker():
    io_loop = IOLoop()
    bokeh_server = Server(
        {
            '/bokeh/price': modify_price_doc,
            '/bokeh/speed': modify_speed_doc,
            '/bokeh/acceleration': modify_acceleration_doc,
            '/bokeh/price_pdf': modify_price_pdf_doc,
            '/bokeh/volume_pdf': modify_volume_pdf_doc,
            '/bokeh/exchange_hist': modify_exchange_hist_doc,
        },
        io_loop=io_loop,
        allow_websocket_origin=["localhost:8050", "localhost:5006"],
        port=5006
    )
    bokeh_server.start()
    io_loop.start()

threading.Thread(target=bk_worker, daemon=True).start()

# Flask route to serve embedded Bokeh apps via iframe.
@server.route('/bokeh/<chart_id>')
def bkapp_page(chart_id):
    script = server_document(f"http://localhost:5006/bokeh/{chart_id}")
    html_page = f"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
        <meta charset="UTF-8">
        <title>TickScope Bokeh Chart - {chart_id}</title>
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
    
# Dash layout generation embedding Bokeh via iframe.
def generate_layout():
    iframe_src = "/bokeh/price"
    return html.Div([
        html.H1(
            f"TickScope: {ticker}",
            style={"text-align": "center", "font-family": "Helvetica, sans-serif"}
        ),
        html.Iframe(
            src="/bokeh/price",
            style={
                "width": "100%",
                "height": "300px",
                "border": "none",
                "background-color": "red",
                "box-sizing": "border-box",
                "overflow": "hidden"
            }
        )
    ], style={"width": "100%", "box-sizing": "border-box"})

app.layout = generate_layout()

# Start WebSocket client for real-time data.
def start_websocket_client():
    ws_client.start_ws_client()

if __name__ == '__main__':
    ws_thread = threading.Thread(target=start_websocket_client, daemon=True)
    ws_thread.start()

    # Run Dash server
    app.run_server(debug=True, use_reloader=False)
