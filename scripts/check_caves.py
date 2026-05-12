import json
import os
BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
ROUTES_F = os.path.join(BASE, 'trailtether_app', 'assets', 'data', 'routes_cleaned.json')
with open(ROUTES_F, 'r', encoding='utf-8') as f:
    routes = json.load(f)
caves = [r for r in routes if 'cave' in r['name'].lower()]
print(f'Total routes: {len(routes)}')
print(f'Cave routes: {len(caves)}')
for c in caves:
    name = c['name']
    dist = c['distanceKm']
    gain = c['elevationGainM']
    diff = c['difficulty']
    print(f'  {name} - {dist}km +{gain}m {diff}')
