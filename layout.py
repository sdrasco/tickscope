"""
layout.py

Defines the Dash layout for Tickscope.
"""
from dash import html, dcc

def create_layout(app):
    return html.Div([
        html.H1("Tickscope"),
        # Embed the Bokeh chart via an IFrame (served from /bokeh)
        html.Iframe(src="/bokeh", style={"width": "100%", "height": "400px", "border": "none"}),
        # An Interval component remains if you need to trigger other callbacks (e.g., for refreshing other data)
        dcc.Interval(id="interval-component", interval=1000, n_intervals=0)
    ])