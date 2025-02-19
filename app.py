"""
app.py

Main entry point for Tickscope.
Initializes the Dash app, sets the layout,
starts the background WebSocket client, and runs the Bokeh server.
"""

import threading
from dash import Dash
from layout import create_layout
import ws_client
from flask import Response, request
from tornado.ioloop import IOLoop
from bokeh.server.server import Server
from charts import modify_doc, reset_chart  # Import reset_chart as well
from flask import render_template_string
from dash.dependencies import Input, Output, State
import requests

# Initialize the Dash app
app = Dash(__name__)
app.layout = create_layout(app)   # Sets the layout (which now includes the Ticker input, header, and buttons)
server = app.server  # Expose the underlying Flask server

# Start the Bokeh server in a background thread.
def bk_worker():
    """
    Starts the Bokeh server to serve the live Bokeh app at '/bkapp'.
    """
    io_loop = IOLoop()
    bokeh_server = Server(
        {'/bkapp': modify_doc},
        io_loop=io_loop,
        allow_websocket_origin=["localhost:8050"],
        port=5006  # Change this port if needed
    )
    bokeh_server.start()
    io_loop.start()

threading.Thread(target=bk_worker, daemon=True).start()

@server.route('/bokeh')
def bkapp_page():
    """
    Returns an HTML page that embeds the live Bokeh app.
    This uses Bokeh's server_document to generate the necessary script.
    """
    from bokeh.embed import server_document
    # Generate the script to connect to the live Bokeh session.
    script = server_document("http://localhost:5006/bkapp")
    html = f"""
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <title>Tickscope Bokeh Chart</title>
    </head>
    <body>
      {script}
    </body>
    </html>
    """
    return Response(html, mimetype='text/html')

@server.route('/reset_chart')
def reset_chart_route():
    """
    Flask route to reset the chart.
    """
    reset_chart()
    return "Chart reset", 200

@server.route('/change_ticker')
def change_ticker_route():
    """
    Flask route to change the ticker symbol.
    Expects a query parameter 'ticker'. Defaults to 'TSLA' if not provided.
    Calls a function in ws_client to update the subscription.
    """
    new_ticker = request.args.get("ticker", "TSLA")
    ws_client.change_ticker(new_ticker)
    return "Ticker changed", 200

# Dash callback for the reset button.
@app.callback(
    Output("reset-status", "children"),
    [Input("reset-chart-button", "n_clicks")]
)
def reset_chart_callback(n_clicks):
    if n_clicks and n_clicks > 0:
        try:
            r = requests.get("http://127.0.0.1:8050/reset_chart")
            if r.status_code == 200:
                return "Chart reset"
            else:
                return "Reset failed"
        except Exception as e:
            return f"Error: {e}"
    return ""

# Dash callback for the Change Ticker button.
# This callback updates two outputs:
# 1. The ticker status message (in "ticker-status").
# 2. A large header displaying the current ticker (in "current-ticker-header").
@app.callback(
    [Output("ticker-status", "children"),
     Output("current-ticker-header", "children")],
    [Input("change-ticker-button", "n_clicks")],
    [State("ticker-input", "value")]
)
def change_ticker_callback(n_clicks, ticker):
    if n_clicks and ticker:
        try:
            r = requests.get(f"http://127.0.0.1:8050/change_ticker?ticker={ticker}")
            if r.status_code == 200:
                status_msg = f"Ticker changed to {ticker}"
                header_msg = f"Current Ticker: {ticker.upper()}"
                return status_msg, header_msg
            else:
                return "Ticker change failed", ""
        except Exception as e:
            return f"Error: {e}", ""
    # On startup, we default to TSLA.
    return "", "Current Ticker: TSLA"

def start_websocket_client():
    """
    Start the WebSocket client in a separate thread.
    This will fetch live data from Polygon.io and update the chart.
    """
    ws_client.start_ws_client()

if __name__ == '__main__':
    # Start the WebSocket client in a background thread.
    ws_thread = threading.Thread(target=start_websocket_client, daemon=True)
    ws_thread.start()
    
    # Run the Dash server with the reloader disabled to prevent duplicate threads.
    app.run_server(debug=True, use_reloader=False)