---
type: data-strategy
status: current
area: data
aliases:
  - Data Strategy
---

# 🗄️ Route Data & Caves

Trailtether's intelligence is driven by specific geographical datasets.

## 🗺️ Routes (Cleaned)
- **Source**: `assets/data/routes_cleaned.json`.
- **Processing**: Pre-processed by the `merge_geojson_routes.py` script to ensure consistent IDs and optimized coordinate sets.
- **Metadata**: Each route includes distance, elevation profiles, and difficulty ratings.

## ⛰️ Caves & POIs
- **Source**: `assets/data/caves.gpx`.
- **Usage**: Specialized points of interest used for mountain safety and shelter location.
- **Audit**: Checked periodically by the `check_caves.py` script for coordinate validity.

## 🏗️ Supabase Integration
- **Table Structure**: Defined in `master_supabase_setup.sql`.
- **Real-time**: Handles live positioning and incident logging for multi-user mission control.
- **Auth**: User authentication is managed natively via `supabase_flutter` with Google Sign-In support.
