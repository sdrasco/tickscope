"""
layout.py

Defines the Dash layout for Tickscope.
"""
from dash import html, dcc

def create_layout(app):
    return html.Div([
        html.H1("Tickscope"),
        # Ticker symbol input section.
        html.Div([
            html.Label("Ticker Symbol:"),
            dcc.Input(id="ticker-input", type="text", value="TSLA"),
            html.Button("Change Ticker", id="change-ticker-button", n_clicks=0),
            html.Div(id="ticker-status"),
        ], style={"margin-bottom": "20px"}),
        # Display current ticker header.
        html.H2("Current Ticker: TSLA", id="current-ticker-header"),
        # Reset button and status message for resetting the chart.
        html.Button("Reset Chart", id="reset-chart-button", n_clicks=0),
        html.Div(id="reset-status"),
        # Embed the Bokeh chart via an IFrame (served from /bokeh)
        html.Iframe(src="/bokeh", style={"width": "100%", "height": "500px", "border": "none"}),
        # An Interval component for periodic callbacks (if needed)
        dcc.Interval(id="interval-component", interval=1000, n_intervals=0)
    ])