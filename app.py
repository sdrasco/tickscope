"""
app.py

Main entry point for Tickscope.
Initializes the Dash app, sets the layout,
and starts the background WebSocket client.
"""

import threading
from bokeh.resources import INLINE
from dash import Dash
from layout import create_layout
import ws_client
from charts import get_chart_components  # used by the /bokeh route
from flask import render_template_string

# Initialize the Dash app
app = Dash(__name__)
server = app.server  # Expose the Flask server

# Register the layout
app.layout = create_layout(app)

# Add a Flask route to serve the Bokeh chart
@server.route('/bokeh')
def bokeh():
    script, div = get_chart_components()
    
    # Get the URLs for BokehJS and CSS resources
    bokeh_js = "\n".join(f'<script src="{js}"></script>' for js in INLINE.js_files)
    bokeh_css = "\n".join(f'<link rel="stylesheet" href="{css}">' for css in INLINE.css_files)
    
    html = """
    <!DOCTYPE html>
    <html lang="en">
    <head>
      <meta charset="UTF-8">
      <title>Tickscope Bokeh Chart</title>
      {bokeh_css}
      {bokeh_js}
    </head>
    <body>
      {div}
      {script}
    </body>
    </html>
    """.format(bokeh_css=bokeh_css, bokeh_js=bokeh_js, div=div, script=script)
    return render_template_string(html)

def start_websocket_client():
    """
    Start the WebSocket client in a separate thread.
    This will fetch live data from Polygon.io.
    """
    ws_client.start_ws_client()

if __name__ == '__main__':
    # Start the WebSocket client in a background thread.
    ws_thread = threading.Thread(target=start_websocket_client, daemon=True)
    ws_thread.start()
    
    # Run the Dash server.
    app.run_server(debug=True)