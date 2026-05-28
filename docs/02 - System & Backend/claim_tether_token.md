---
tags: [type/endpoint, type/rpc, layer/db, status/stable, domain/pairing]
aliases: [public.claim_tether_token]
source_paths: []
---

# claim_tether_token

**RPC** `public.claim_tether_token(p_token text) returns jsonb` (SECURITY DEFINER)

Mobile-side handler for the PC ↔ mobile pairing flow. Mobile user scans a QR code on the PC screen → calls this with the token → server marks the [[tether_pairings]] row claimed → PC sees the realtime update.

## Validation

- Token must exist
- `expires_at > now()`
- `claimed_by_uid is null` (not already claimed)

## Side effects

- Sets `claimed_by_uid = auth.uid()`, `claimed_at = now()`

## Callers

- Mobile QR scanner UI
