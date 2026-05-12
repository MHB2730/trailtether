"""
merge_geojson_routes.py
-----------------------
Reads the GEOJSON extracted from trailtether.html and merges all track
features into the Flutter app's routes.json asset.

- Keeps existing routes.json entries unchanged (they have clean metadata).
- Adds NEW routes (found in GEOJSON but missing from routes.json) with
  auto-computed stats (distance, elevation gain/loss, Naismith time,
  difficulty from gain/km ratio).
- Writes the merged result back to routes.json.
"""

import json
import math
import re
import os

# ── Paths ─────────────────────────────────────────────────────────────────
BASE      = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
GEOJSON_F = os.path.join(BASE, 'temp_geojson.json')
ROUTES_F  = os.path.join(BASE, 'trailtether_app', 'assets', 'data', 'routes_cleaned.json')

# ── Helpers ───────────────────────────────────────────────────────────────
def haversine_m(a, b):
    """Distance in metres between two [lon, lat] points."""
    R = 6371000.0
    lat1, lat2 = math.radians(a[1]), math.radians(b[1])
    dLat = lat2 - lat1
    dLon = math.radians(b[0] - a[0])
    h = math.sin(dLat/2)**2 + math.cos(lat1)*math.cos(lat2)*math.sin(dLon/2)**2
    return 2 * R * math.asin(math.sqrt(h))

def compute_stats(coords):
    """Return (distanceKm, gainM, lossM) from [[lon,lat,ele], ...] coords."""
    dist_m   = 0.0
    gain_m   = 0.0
    loss_m   = 0.0
    for i in range(1, len(coords)):
        dist_m += haversine_m(coords[i-1], coords[i])
        if len(coords[i]) > 2 and len(coords[i-1]) > 2:
            diff = coords[i][2] - coords[i-1][2]
            if diff > 0.5:
                gain_m += diff
            elif diff < -0.5:
                loss_m += abs(diff)
    return round(dist_m / 1000, 2), int(gain_m), int(loss_m)

def naismith_hours(dist_km, gain_m):
    """Naismith rule estimate in hours."""
    walk = dist_km / 5.0
    climb = gain_m / 600.0
    return round(walk + climb, 2)

def assign_difficulty(gain_m, dist_km):
    ratio = gain_m / max(dist_km, 0.1)  # m/km
    if ratio < 50:
        return 'Easy'
    elif ratio < 120:
        return 'Moderate'
    elif ratio < 250:
        return 'Hard'
    else:
        return 'Extreme'

def name_to_id(name):
    """Convert a display name to a filesystem-safe snake_case id."""
    s = name.lower()
    s = re.sub(r"['\u2019\u2018]", '', s)   # remove apostrophes
    s = re.sub(r'[^a-z0-9]+', '_', s)        # non-alphanum → underscore
    s = s.strip('_')
    return s

# ── Load existing routes ──────────────────────────────────────────────────
print('Loading routes.json …')
with open(ROUTES_F, 'r', encoding='utf-8') as f:
    existing_routes = json.load(f)

existing_ids   = {r['id'] for r in existing_routes}
existing_names = {r['name'].lower() for r in existing_routes}
print(f'  Existing routes: {len(existing_routes)}')

# ── Load GEOJSON ──────────────────────────────────────────────────────────
print('Loading GEOJSON …')
with open(GEOJSON_F, 'r', encoding='utf-8-sig') as f:
    geojson = json.load(f)

features = geojson.get('features', [])
track_features = [f for f in features if f.get('properties', {}).get('type') == 'track']
print(f'  Total features: {len(features)}, track features: {len(track_features)}')

# ── Convert and merge ─────────────────────────────────────────────────────
new_routes = []
skipped    = 0
added      = 0

for feat in track_features:
    props  = feat.get('properties', {})
    name   = props.get('name', '').strip()
    if not name:
        skipped += 1
        continue

    geom   = feat.get('geometry', {})
    coords = geom.get('coordinates', [])
    if len(coords) < 2:
        skipped += 1
        continue

    # Generate candidate id
    rid = name_to_id(name)

    # Skip if already present (by id or name)
    if rid in existing_ids or name.lower() in existing_names:
        skipped += 1
        continue

    # Compute stats
    dist_km, gain_m, loss_m = compute_stats(coords)
    mins = props.get('min_ele', 0)
    maxs = props.get('max_ele', 0)

    # If min/max not set, compute from coordinates
    eles = [c[2] for c in coords if len(c) > 2 and c[2] != 0]
    if not mins and eles:
        mins = int(min(eles))
    if not maxs and eles:
        maxs = int(max(eles))

    route = {
        'id':             rid,
        'name':           name,
        'distanceKm':     dist_km,
        'elevationGainM': gain_m,
        'elevationLossM': loss_m,
        'estTimeHours':   naismith_hours(dist_km, gain_m),
        'difficulty':     assign_difficulty(gain_m, dist_km),
        'minEle':         mins,
        'maxEle':         maxs,
        'description':    '',
        'coords':         coords,
    }
    new_routes.append(route)
    added += 1

print(f'\nSkipped (already exist or no coords): {skipped}')
print(f'New routes to add: {added}')

# ── Write merged result ───────────────────────────────────────────────────
merged = existing_routes + new_routes

# Sort: existing first (preserves their order), then new alphabetically
merged_sorted = existing_routes + sorted(new_routes, key=lambda r: r['name'].lower())

print(f'\nTotal routes after merge: {len(merged_sorted)}')

with open(ROUTES_F, 'w', encoding='utf-8') as f:
    json.dump(merged_sorted, f, separators=(',', ':'))

print(f'Written to {ROUTES_F}')

# Print sample of added routes
if new_routes:
    print('\nSample of added routes:')
    cave_routes = [r for r in new_routes if 'cave' in r['name'].lower()]
    sample = cave_routes[:10] if cave_routes else new_routes[:10]
    for r in sample:
        print(f"  [{r['id']}] {r['name']} — {r['distanceKm']}km, +{r['elevationGainM']}m, {r['difficulty']}")
