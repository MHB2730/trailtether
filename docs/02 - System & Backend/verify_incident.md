---
tags: [type/endpoint, type/rpc, layer/db, status/stable, domain/safety]
aliases: [public.verify_incident]
source_paths: []
---

# verify_incident

**RPC** `public.verify_incident(p_incident_id uuid)` (SECURITY DEFINER, authenticated)

Community-moderation: marks an incident as confirmed by another user (increments `verify_count`).

## Overloads

Two definitions exist in production:
- `verify_incident(p_incident_id uuid)` (uses `auth.uid()`)
- `verify_incident(p_incident_id uuid, p_uid uuid)` (explicit uid — admin override)

## Callers

- Incident detail sheet "Verify" button

## See also

- [[flag_incident]] — opposite action (community downvote)
- [[incidents]]
