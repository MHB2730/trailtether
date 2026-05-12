# 🎨 Stitch Design System

Trailtether uses a custom-built design system called **Stitch** for its UI/UX, optimized for outdoor visibility and night hiking.

## 🌈 Color Palette
- **Primary Bg**: `#0D0D0D` (Near-black)
- **Accent Orange**: `#E8541A` (Tactical orange)
- **Cream**: `#E8DFC8` (Off-white for readability)
- **Cyan**: `#00F2FF` (Used in 3D views)
- **Purple**: `#9D00FF` (Used in 3D views)
- **Glass**: `10% White` opacity for panels.

## ✍️ Typography
- **Primary Font**: **Inter** (via Google Fonts).
- **Styles**: Defined for Headers, Buttons, Body, and Metadata to ensure consistent hierarchy across platforms.

## 🌙 Night Map Mode
A specialized feature for late-hour navigation:
- **Base Layer**: Stadia Alidade Smooth Dark.
- **Visual Treatment**: The UI applies a **Red ColorFiltered overlay** across the map.
- **Purpose**: Preserves the operator's **night vision** while still providing full topographical situational awareness.

## 🗺️ Map Styles & Providers
The app offers a multi-provider tile selector:
1. **OpenTopoMap**: Default for hiking (includes contour lines and trail markings).
2. **Esri World Topo**: Professional-grade topographical styling.
3. **Esri World Imagery**: Satellite base layer.
4. **Stadia Maps**: Optimized dark basemaps for night mode.
5. **MapTiler**: Premium 3D and Outdoor styles (requires dynamic API key injection).
