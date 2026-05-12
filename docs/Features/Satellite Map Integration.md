# Satellite Map Integration

## Implementation
- **Library**: Leaflet.js
- **Provider**: [Satellite Tile Provider Name/URL]
- **Toggle**: Managed via the Mission Control dashboard.

## Logic Unification
The logic for triggering detail sheets is shared between:
- `Leaflet` (2D)
- `WebView2` (3D/Satellite)

This ensures that clicking a unit on either map type opens the same information panel.
