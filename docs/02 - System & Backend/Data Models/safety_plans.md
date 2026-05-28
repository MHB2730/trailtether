---
tags: [type/model, layer/db, status/stable, domain/safety]
aliases: [public.safety_plans]
source_paths: []
---

# safety_plans

Pre-trail safety plans. "I'm going to do X, due back by Y, contact Z if I'm not".

## Schema (key columns)

| Column | Type |
|---|---|
| id | uuid PK |
| user_id | uuid → profiles.id |
| trail_id | text (nullable) |
| trail_name | text |
| expected_return | timestamptz |
| notes | text |
| emergency_contact | jsonb |
| status | text (active / completed / overdue / cancelled) |
| last_ping_at | timestamptz |
| created_at, updated_at | timestamptz |

## CRUD locations

- **Created** by [[app_state_provider.dart]] `setSafetyPlan` (mobile)
- **Pinged** via [[ping_safety_plan]] RPC during recording
- **Overdue detection** server-side (likely cron — verify)

> [!warning] Verify
> Schema reasoned from [[app_state_provider.dart]] usage. Confirm columns by reading the table directly if exact fields matter.
