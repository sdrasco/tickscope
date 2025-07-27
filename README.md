# Tickscope

Tickscope is a macOS SwiftUI application for real-time tracking of stock and options tick data using the [Polygon.io](https://polygon.io) WebSocket API. It visualizes trades, quotes and volumes for both a stock symbol and a selected option contract.

## Features

- Live charts for traded stock price and trade volume.
- Live charts for option premium and option trade volume.
- Bid/Ask quote charts for both stock and option data.
- Input field to monitor any option ticker.
- Polygon API key stored securely in the macOS Keychain.

## Requirements

- macOS 13.5 or later.
- Xcode 15 or newer with Swift and SwiftUI support.
- A valid Polygon API key.

## Running the App

1. Clone this repository.
2. Open `tickscope.xcodeproj` in Xcode 15 or later.
3. Build and run the `tickscope` target.
4. On first launch you will be prompted to enter your Polygon API key. This key is saved using `KeychainManager` and automatically retrieved on future launches.

The app connects to Polygon's WebSocket endpoints and streams trade and quote data. Data is kept in memory for a short period (about 3–5 minutes as configured in `Config.swift`).

## Limitations

- Requires an active internet connection and a valid Polygon subscription.
- Limited error handling for WebSocket failures or invalid input.
- Only shows recent data; historical data is not persisted.

## License

This project is licensed under the [MIT License](LICENSE). © 2025 Steve Drasco.

## Author

Steve Drasco
