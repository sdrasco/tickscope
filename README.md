<p align="center">
  <img src="docs/images/tickscope_small_logo.png" alt="Tickscope Logo">
</p>

## Tickscope

Tickscope is a Python-based web application for monitoring live trading data in real time. It leverages Dash for the user interface, Bokeh for interactive charting, and websockets to stream live data from Polygon.io.

It’s for those who think standard trading charts aren’t quite obsessive enough. If you’ve ever wanted to see every single trade—yes, every last one—this is for you. Most people probably don’t, but that’s fine, we’re not here for them. Just be aware that you’ll need a **Polygon.io "Stocks Advanced" subscription** for this to work properly. Without it, Tickscope is essentially a very enthusiastic but uninformed chart.

## Project Progress Highlights

- **2025-02-19**: The thing works. You can now watch trades roll in one by one. Try not to get hypnotized.

## Running Tickscope

1. **Clone the Repository:**
   ```sh
   git clone https://github.com/yourusername/tickscope.git
   cd tickscope
   ```
2. **Create and Activate a Virtual Environment:**
   ```sh
   python -m venv venv
   source venv/bin/activate    # On macOS/Linux
   venv\Scripts\activate       # On Windows
   ```
3. **Install the Dependencies:**
   ```sh
   pip install -r requirements.txt
   ```
4. **Edit Configuration:**
   Update `config.py` with your Polygon.io API key:
   ```python
   POLYGONIO_API_KEY = "your_api_key_here"
   WS_ENDPOINT = "wss://socket.polygon.io/stocks"
   ```
   Remember, **you need a "Stocks Advanced" subscription on Polygon.io** for this to function properly. Otherwise, enjoy a blank chart.

5. **Start the Application:**
   ```sh
   python app.py
   ```
   Then open your browser and navigate to [http://localhost:8050](http://localhost:8050).

## License

This project is licensed under the MIT License.