"""
charts.py

Bokeh chart classes and server integration functions
for real-time plotting of stocks and options in Tickscope.
"""

import math
from bokeh.plotting import figure
from bokeh.models import ColumnDataSource, Range1d
from datetime import datetime

# Global references for Bokeh documents
bokeh_docs = {}

# -------------------------------
# Base Chart Class
# -------------------------------

class BaseChart:
    def __init__(
        self,
        x_axis_type="datetime",
        sizing_mode="scale_width",
        height=300,
        toolbar_location=None,
        min_border_bottom=50,
        x_axis_label=None,
        y_axis_label=None
    ):
        self.sizing_mode = sizing_mode
        self.height = height
        self.toolbar_location = toolbar_location
        self.min_border_bottom = min_border_bottom
        self.x_axis_label = x_axis_label
        self.y_axis_label = y_axis_label
        self.source = ColumnDataSource(data=dict(time=[], price=[], alpha=[]))
        self.chart = None

    def create_figure(self):
        self.chart = figure(
            x_axis_type="datetime",
            sizing_mode=self.sizing_mode,
            height=self.height,
            toolbar_location=self.toolbar_location
        )
        self.chart.min_border_bottom = self.min_border_bottom

        if self.x_axis_label:
            self.chart.xaxis.axis_label = self.x_axis_label
        if self.y_axis_label:
            self.chart.yaxis.axis_label = self.y_axis_label

        self.chart.y_range = Range1d(start=0, end=1)
        return self.chart

    def update_y_range(self, y_data):
        if y_data:
            min_val, max_val = min(y_data), max(y_data)
            pad = (max_val - min_val) * 0.1 or 1.0
            self.chart.y_range.start = min_val - pad
            self.chart.y_range.end = max_val + pad

    @staticmethod
    def compute_alpha(trade_size):
        if trade_size < 1:
            return 0.2
        alpha = 0.2 + 0.8 * (math.log(trade_size) / math.log(10000))
        return min(max(alpha, 0.2), 1.0)

# -------------------------------
# Chart Subclasses
# -------------------------------

class PriceChart(BaseChart):
    def __init__(self, **kwargs):
        super().__init__(y_axis_label="Traded Stock Price ($)", **kwargs)

    def create_figure(self):
        fig = super().create_figure()
        fig.scatter(x="time", y="price", source=self.source, size=8, color="navy", alpha="alpha")
        return fig

    def update_chart(self, price, timestamp, size):
        alpha = self.compute_alpha(size)
        new_data = dict(time=[timestamp], price=[price], alpha=[alpha])
        self.source.stream(new_data, rollover=2500)
        self.update_y_range(self.source.data["price"])

class OptionPriceChart(BaseChart):
    def __init__(self, **kwargs):
        super().__init__(y_axis_label="Traded Option Premium ($)", **kwargs)

    def create_figure(self):
        fig = super().create_figure()
        fig.scatter(x="time", y="price", source=self.source, size=8, color="green", alpha="alpha")
        return fig

    def update_chart(self, price, timestamp, size):
        alpha = self.compute_alpha(size)
        new_data = dict(time=[timestamp], price=[price], alpha=[alpha])
        self.source.stream(new_data, rollover=2500)
        self.update_y_range(self.source.data["price"])

class BidAskSpreadChart(BaseChart):
    def __init__(self, **kwargs):
        super().__init__(y_axis_label="Bid (red) Ask (blue)  w($)", **kwargs)
        self.source = ColumnDataSource(data=dict(time=[], bid=[], ask=[]))

    def create_figure(self):
        fig = super().create_figure()

        # Plot bid data with muted colors
        fig.line(x="time", y="bid", source=self.source, line_width=2, color="#c44e52")

        # Plot ask data
        fig.line(x="time", y="ask", source=self.source, line_width=2, color="#4c72b0")

        return fig

    def update_chart(self, bid, ask, timestamp):
        new_data = dict(time=[timestamp], bid=[bid], ask=[ask])
        self.source.stream(new_data, rollover=2500)
        self.update_y_range(self.source.data["bid"] + self.source.data["ask"])

class StockVolumeHeartbeatChart(BaseChart):
    def __init__(self, **kwargs):
        super().__init__(y_axis_label="Volume (shares)", **kwargs)
        self.source = ColumnDataSource(data=dict(time=[], volume=[]))

    def create_figure(self):
        fig = super().create_figure()
        fig.vbar(x="time", top="volume", width=500, source=self.source, color="purple")
        return fig

    def update_chart(self, volume, timestamp):
        new_data = dict(time=[timestamp], volume=[volume])
        self.source.stream(new_data, rollover=2500)
        self.update_y_range(self.source.data["volume"])

class OptionVolumeHeartbeatChart(BaseChart):
    def __init__(self, **kwargs):
        super().__init__(y_axis_label="Volume (contracts)", **kwargs)
        self.source = ColumnDataSource(data=dict(time=[], volume=[]))

    def create_figure(self):
        fig = super().create_figure()
        fig.vbar(x="time", top="volume", width=500, source=self.source, color="purple")
        return fig

    def update_chart(self, volume, timestamp):
        new_data = dict(time=[timestamp], volume=[volume])
        self.source.stream(new_data, rollover=2500)
        self.update_y_range(self.source.data["volume"])


# -------------------------------
# Integration Functions for Bokeh Server
# -------------------------------

def modify_doc(doc_name, chart_class, doc):
    chart = chart_class()
    fig = chart.create_figure()
    doc.clear()
    doc.add_root(fig)
    doc.chart_obj = chart
    bokeh_docs[doc_name] = doc

def modify_price_doc(doc):
    modify_doc('stock_price', PriceChart, doc)

def modify_option_price_doc(doc):
    modify_doc('option_price', OptionPriceChart, doc)

def modify_stock_bidask_doc(doc):
    modify_doc('stock_bidask', BidAskSpreadChart, doc)

def modify_option_bidask_doc(doc):
    modify_doc('option_bidask', BidAskSpreadChart, doc)

def modify_stock_volume_doc(doc):
    modify_doc('stock_volume', StockVolumeHeartbeatChart, doc)

def modify_option_volume_doc(doc):
    modify_doc('option_volume', OptionVolumeHeartbeatChart, doc)

# -------------------------------
# Update functions
# -------------------------------

def update_price_doc(price, timestamp, size):
    doc = bokeh_docs.get('stock_price')
    if doc and hasattr(doc, "chart_obj"):
        doc.add_next_tick_callback(lambda: doc.chart_obj.update_chart(price, timestamp, size))

def update_option_price_doc(price, timestamp, size):
    doc = bokeh_docs.get('option_price')
    if doc:
        doc.chart_obj.update_chart(price, timestamp, size)

def update_stock_bidask_doc(bid, ask, timestamp):
    doc = bokeh_docs.get('stock_bidask')
    if doc and hasattr(doc, "chart_obj"):
        doc.chart_obj.update_chart(bid, ask, timestamp)

def update_option_bidask_doc(bid, ask, timestamp):
    doc = bokeh_docs.get('option_bidask')
    if doc and hasattr(doc, "chart_obj"):
        doc.chart_obj.update_chart(bid, ask, timestamp)

def update_stock_volume_doc(volume, timestamp):
    doc = bokeh_docs.get('stock_volume')
    if doc and hasattr(doc, "chart_obj"):
        doc.chart_obj.update_chart(volume, timestamp)

def update_option_volume_doc(volume, timestamp):
    doc = bokeh_docs.get('option_volume')
    if doc and hasattr(doc, "chart_obj"):
        doc.chart_obj.update_chart(volume, timestamp)
        
# -------------------------------
# Ensure all Bokeh Docs references initialized
# -------------------------------
bokeh_docs = {
    'stock_price': None,
    'option_price': None,
    'stock_bidask': None,
    'option_bidask': None,
    'stock_volume': None,
    'option_volume': None
}

