"""
charts.py

Module for creating and updating a live Bokeh price chart.
This chart displays real-time price updates using a scatter plot,
served by a Bokeh server, with a dynamic y-axis range that adjusts
to the data and point opacity (alpha) based on trade size.
It also includes functionality to reset the chart.
"""

import math
from bokeh.plotting import figure
from bokeh.models import ColumnDataSource, Range1d
from datetime import datetime
from tornado.ioloop import IOLoop

# Global data source used for live updates.
# Added an 'alpha' column for point opacity.
global_source = ColumnDataSource(data=dict(time=[], price=[], alpha=[]))

# Global variables for the Bokeh server's IOLoop and Document.
bk_io_loop = None
bokeh_doc = None

# Global list to store pending updates if the document is not yet ready.
pending_updates = []

def compute_alpha(trade_size):
    """
    Compute a continuous alpha value based on trade size using a logarithmic scale.
    - For trade_size = 1, returns ~0.2.
    - For trade_size = 10,000 or higher, returns 1.0.
    Values in between are scaled logarithmically.
    """
    if trade_size < 1:
        return 0.2
    alpha = 0.2 + 0.8 * (math.log(trade_size) / math.log(10000))
    return min(max(alpha, 0.2), 1.0)

def stream_update(new_data):
    """Helper function to stream an update and then adjust the y-range dynamically."""
    global_source.stream(new_data, rollover=10000)
    update_y_range()

def update_y_range():
    """
    Dynamically adjust the y-axis range based on current data,
    adding 10% padding to the min and max.
    """
    data = global_source.data.get("price", [])
    if data and bokeh_doc is not None and hasattr(bokeh_doc, "chart_figure"):
        chart = bokeh_doc.chart_figure
        min_val = min(data)
        max_val = max(data)
        pad = (max_val - min_val) * 0.1
        if pad == 0:
            pad = 1.0
        chart.y_range.start = min_val - pad
        chart.y_range.end = max_val + pad

def flush_pending_updates():
    """Flush all queued updates once the Bokeh document is available."""
    global pending_updates
    if bokeh_doc is not None:
        while pending_updates:
            new_price, timestamp, trade_size = pending_updates.pop(0)
            alpha_value = compute_alpha(trade_size)
            new_data = dict(time=[timestamp], price=[new_price], alpha=[alpha_value])
            try:
                bokeh_doc.add_next_tick_callback(lambda nd=new_data: stream_update(nd))
            except Exception as e:
                print("Error flushing pending update:", e)

def modify_doc(doc):
    global bk_io_loop, bokeh_doc, global_source
    bk_io_loop = IOLoop.current()
    bokeh_doc = doc

    # If the global_source is already attached to a document, create a new copy.
    if global_source.document is not None:
        global_source = ColumnDataSource(data=global_source.data)

    # Create a new chart for this session.
    chart = figure(
        title="Live Price Chart",
        x_axis_type="datetime",
        x_axis_label="Time",
        y_axis_label="Price",
        height=500,
        sizing_mode="stretch_width"
    )
    chart.xaxis.axis_label_standoff = 40
    chart.min_border_bottom = 100
    chart.y_range = Range1d(start=0, end=1)
    chart.scatter(x="time", y="price", source=global_source, size=8, color="navy", alpha="alpha")
    
    doc.clear()  # Clear any previous roots in this document.
    doc.add_root(chart)
    # Save a reference to the chart on the document for later use.
    doc.chart_figure = chart

    flush_pending_updates()
    return doc

def update_price_chart(new_price, timestamp, trade_size):
    """
    Updates the global data source with a new price point.
    Schedules the update on the Bokeh document's next tick to ensure thread safety.
    
    Parameters:
        new_price (float): The new price to add to the chart.
        timestamp (datetime): The timestamp associated with the new price.
        trade_size (int): The size of the trade.
    """
    alpha_value = compute_alpha(trade_size)
    new_data = dict(time=[timestamp], price=[new_price], alpha=[alpha_value])
    
    if bokeh_doc is not None:
        try:
            flush_pending_updates()
            bokeh_doc.add_next_tick_callback(lambda nd=new_data: stream_update(nd))
        except Exception as e:
            print("Error updating Bokeh data source:", e)
    else:
        pending_updates.append((new_price, timestamp, trade_size))

def reset_chart():
    """Resets the chart data and y-axis range."""
    global_source.data = dict(time=[], price=[], alpha=[])
    if bokeh_doc is not None and hasattr(bokeh_doc, "chart_figure"):
        chart = bokeh_doc.chart_figure
        chart.y_range.start = 0
        chart.y_range.end = 1