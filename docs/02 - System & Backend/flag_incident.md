---
tags: [type/endpoint, type/rpc, layer/db, status/stable, domain/safety]
aliases: [public.flag_incident, increment_flag_count]
source_paths: []
---

# flag_incident

**RPC** `public.flag_incident(p_incident_id uuid)` (SECURITY DEFINER, authenticated)

Community moderation: flag an incident as spam/misleading. Companion to `increment_flag_count(p_incident_id)`.

## Side effects

- Increments `flag_count` on [[incidents]]
- Auto-hides the incident from feeds once `flag_count` crosses a threshold (verify exact value)

## Callers

- Incident detail sheet "Flag" button

## See also

- [[verify_incident]]
- [[incidents]]
