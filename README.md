# MultiBank Stock Tracker

A small SwiftUI app for browsing 25 stocks, sorting the watchlist, and seeing price updates on the list and detail screens.

Prices are sample data. The app simulates changes and sends them through the Postman WebSocket echo service; they are not live market prices.

## Run

Open `StockTracker.xcodeproj` in Xcode, choose the `StockTracker` scheme and an iOS 17+ simulator, then run. Tap **Start Price Feed** on the Markets screen to begin updates.

## Test

Run **Product > Test** in Xcode, or use:

```sh
xcodebuild test \
  -project StockTracker.xcodeproj \
  -scheme StockTracker \
  -destination 'platform=iOS Simulator,name=iPhone 17' \
  CODE_SIGNING_ALLOWED=NO
```

Feed tests use a fake socket, so they don't need a network connection.

## Project structure

- `Models/` — stock data and feed states
- `Services/` — catalog loading and WebSocket feed
- `ViewModels/` — shared stock data, sorting, and feed actions
- `Views/` — watchlist and stock detail screens
- `StockTrackerTests/` — model and feed tests

The watchlist starts in A–Z order. You can also sort by price or price change. Swift section markers follow the required `// MARK:  -  Name  -  ` format.
