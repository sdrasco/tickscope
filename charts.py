"""
charts.py

Module for creating and updating a Bokeh price chart.
This chart will display live price updates using a line plot.
"""

from bokeh.plotting import figure
from bokeh.models import ColumnDataSource
from bokeh.embed import components
from datetime import datetime

# Create a ColumnDataSource to hold the time and price data
source = ColumnDataSource(data=dict(time=[], price=[]))

def create_price_chart():
    """
    Creates and returns a Bokeh figure configured for live price updates.

    Returns:
        bokeh.plotting.figure: The Bokeh figure object.
    """
    p = figure(title="Live Price Chart", x_axis_type="datetime",
               x_axis_label="Time", y_axis_label="Price",
               sizing_mode="stretch_width", height=400)
    p.line(x="time", y="price", source=source, line_width=2, legend_label="Price")
    p.legend.location = "top_left"
    return p

def update_price_chart(new_price):
    """
    Updates the Bokeh chart's data source with a new price point.
    The current timestamp is used as the x-axis value.

    Parameters:
        new_price (float): The new price to add to the chart.
    """
    # Get current time as a datetime object
    current_time = datetime.now()
    
    # Append new data to the ColumnDataSource
    new_data = dict(time=[current_time], price=[new_price])
    source.stream(new_data, rollover=60)  # Keeps only the latest 60 entries

def get_chart_components():
    """
    Creates the chart and returns the HTML components (script and div)
    for embedding into a Dash layout or a standalone HTML page.

    Returns:
        tuple: (script, div) containing the Bokeh embed components.
    """
    chart = create_price_chart()
    return components(chart)