# 🛰️ Route & GPX Management

Trailtether is built to handle complex trail data and user-uploaded routes.

## 📤 GPX Processing
The app includes a custom client-side GPX parser (`processGPX`):
- **XML Parsing**: Uses `DOMParser` to extract `trkpt` and `rtept` data.
- **Metrics Calculation**:
  - **Distance**: Calculated using the **Haversine Formula** for earth-curvature accuracy.
  - **Elevation Gain**: Derived by summing positive elevation changes between points (with a 0.5m noise threshold).
- **Auto-ID**: New routes are assigned IDs prefixed with `user_`.

## 📈 Elevation Profiles
- **Visualization**: Powered by **Chart.js**.
- **Data Source**: The `profile` array in each route object (index vs. elevation).
- **Interaction**: Selecting a route in the sidebar highlights the path on the map and populates the profile chart.

## 🔍 Search & Filtering
- **Fuzzy Search**: Sidebar search filters the route list and applies a `match` filter to the MapLibre layer simultaneously.
- **Fit View**: "Fit All" calculates the bounding box of all loaded coordinates to zoom the map to the full project scope.
