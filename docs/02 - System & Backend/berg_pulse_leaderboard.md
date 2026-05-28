---
tags: [type/endpoint, type/rpc, layer/db, status/stable, domain/community]
aliases: [public.berg_pulse_leaderboard]
source_paths: [supabase/migrations/20260527_berg_live_views_rpcs.sql]
---

# berg_pulse_leaderboard

**RPC** `public.berg_pulse_leaderboard(p_metric text default 'km', p_limit int default 25) returns setof <row>` (SECURITY DEFINER, anon-callable)

Returns Berg Live leaderboard ranked by chosen metric.

## Params

| Param | Note |
|---|---|
| `p_metric` | `km` / `hikes` / `ascent_m` |
| `p_limit` | top N rows |

## Output (per row)

Ranking + team or hiker display info — only safe fields (no PII):
- For teams: `public_display_name`, total_km, hike_count
- For hikers: `display_name`, photo_url, total_km

## Privacy

Only `is_public=true` teams included. Personal hikers must have `is_admin OR explicit consent` (verify exact flag). See [[teams]] consent model.

## Callers

- `hilltrek-site/pulse/index.html` (ranks list)

## See also

- [[berg_pulse_stats]] (other Berg pulse RPCs)
