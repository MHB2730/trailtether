# System Overview

Trailtether is designed for high-reliability field telemetry. 

## High-Level Architecture
- **Frontend**: Single Page Application (SPA) using vanilla JS/CSS for performance.
- **Desktop Wrapper**: Electron with WebView2 for advanced map rendering on Windows.
- **Mobile Wrapper**: Capacitor for cross-platform Android deployment.
- **Data Flow**: Real-time GPS coordinates are pushed to Firebase and synced across all active Mission Control consoles.

## Key Components
1. **Mission Control**: Dashboard for monitoring all field units.
2. **Telemetry Engine**: Background service for tracking and SOS listening.
3. **Map Interface**: Unified logic for 2D Leaflet and 3D Satellite views.
