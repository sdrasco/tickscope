# charts.py

import math
from bokeh.plotting import figure
from bokeh.models import ColumnDataSource, Range1d
from tornado.ioloop import IOLoop
from datetime import datetime

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

    def update_y_range(self):
        data = self.source.data.get("price", [])
        if data:
            min_val, max_val = min(data), max(data)
            pad = (max_val - min_val) * 0.1 or 1.0
            self.chart.y_range.start = min_val - pad
            self.chart.y_range.end = max_val + pad

    def update_chart(self, new_price, timestamp, trade_size):
        alpha_value = self.compute_alpha(trade_size)
        new_data = dict(time=[timestamp], price=[new_price], alpha=[alpha_value])
        self.source.stream(new_data, rollover=2500)
        self.update_y_range()

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
        super().__init__(y_axis_label="price ($)", **kwargs)

    def create_figure(self):
        fig = super().create_figure()
        fig.scatter(
            x="time", y="price", source=self.source,
            size=8, color="navy", alpha="alpha"
        )
        return fig

class SpeedChart(BaseChart):
    def __init__(self, **kwargs):
        super().__init__(y_axis_label="speed ($/s)", **kwargs)

class AccelerationChart(BaseChart):
    def __init__(self, **kwargs):
        super().__init__(y_axis_label="acceleration ($/s²)", **kwargs)

class PricePDFChart(BaseChart):
    def __init__(self, **kwargs):
        super().__init__(x_axis_label="price ($)", **kwargs)

class VolumePDFChart(BaseChart):
    def __init__(self, **kwargs):
        super().__init__(x_axis_label="volume (shares)", **kwargs)

class ExchangeHistChart(BaseChart):
    def __init__(self, **kwargs):
        super().__init__(x_axis_label="exchange (id)", **kwargs)

# -------------------------------
# Integration Functions for Bokeh Server
# -------------------------------

bk_io_loop = None
bokeh_doc = None

def modify_price_doc(doc):
    global bk_io_loop, bokeh_doc
    bk_io_loop = IOLoop.current()
    bokeh_doc = doc

    price_chart = PriceChart(toolbar_location=None)
    fig = price_chart.create_figure()
    doc.clear()
    doc.add_root(fig)
    doc.chart_obj = price_chart
    return doc

def update_price_doc(new_price, timestamp, trade_size):
    if hasattr(bokeh_doc, "chart_obj"):
        bokeh_doc.chart_obj.update_chart(new_price, timestamp, trade_size)

def modify_speed_doc(doc):
    speed_chart = SpeedChart(toolbar_location=None)
    fig = speed_chart.create_figure()
    doc.clear()
    doc.add_root(fig)
    doc.chart_obj = speed_chart
    return doc

def modify_acceleration_doc(doc):
    acceleration_chart = AccelerationChart(toolbar_location=None)
    fig = acceleration_chart.create_figure()
    doc.clear()
    doc.add_root(fig)
    doc.chart_obj = acceleration_chart
    return doc

def modify_price_pdf_doc(doc):
    price_pdf_chart = PricePDFChart(toolbar_location=None)
    fig = price_pdf_chart.create_figure()
    doc.clear()
    doc.add_root(fig)
    doc.chart_obj = price_pdf_chart
    return doc

def modify_volume_pdf_doc(doc):
    volume_pdf_chart = VolumePDFChart(toolbar_location=None)
    fig = volume_pdf_chart.create_figure()
    doc.clear()
    doc.add_root(fig)
    doc.chart_obj = volume_pdf_chart
    return doc

def modify_exchange_hist_doc(doc):
    exchange_hist_chart = ExchangeHistChart(toolbar_location=None)
    fig = exchange_hist_chart.create_figure()
    doc.clear()
    doc.add_root(fig)
    doc.chart_obj = exchange_hist_chart
    return doc
