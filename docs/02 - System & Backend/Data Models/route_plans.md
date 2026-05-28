---
tags: [type/model, layer/db, status/stable, domain/routing]
aliases: [public.route_plans, public.route_waypoints]
source_paths: []
---

# route_plans (+ route_waypoints)

Planned routes — sequence of waypoints to follow. Distinct from a saved (recorded) hike.

## Schema (route_plans, key columns)

| Column | Type |
|---|---|
| id | uuid PK |
| user_id | uuid → profiles.id |
| team_id | uuid (nullable) |
| name | text |
| total_distance_km | numeric |
| total_elevation_gain_m | int |
| created_at, updated_at | timestamptz |

## Schema (route_waypoints, key columns)

| Column | Type |
|---|---|
| id | uuid PK |
| route_plan_id | uuid → route_plans.id (CASCADE) |
| ordinal | int (sequence index) |
| lat, lon, ele | numeric |
| name | text (optional) |

## Trigger

`_touch_route_plans_updated_at` bumps updated_at on UPDATE.

## CRUD locations

- **Created/Edited** by mobile route planner UI
- **Read** by [[routing_provider.dart]] (active plan)
