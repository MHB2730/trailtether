---
tags: [type/dep, layer/backend, status/stable, domain/backend]
aliases: [supabase-js, '@supabase/supabase-js']
source_paths: [supabase/functions]
---

# supabase-js

Backend client SDK used by every edge function. Two import paths in use across functions:

| Import | Used by |
|---|---|
| `jsr:@supabase/supabase-js@2` | Most newer functions (apk-download-gate, analytics-ingest, health-pinger, newsletter-track-*, newsletter-send, subscriber-send-confirmation, publish-site) |
| `https://esm.sh/@supabase/supabase-js@2.45.0` | Older payment functions (payfast-checkout, yoco-checkout, zapper-checkout, payfast-itn, yoco-webhook, zapper-webhook, finalize-orphan-hikes) |

> [!warning] Verify
> Two import paths is non-ideal. Supabase now recommends `jsr:` exclusively. Worth standardising. Listed in [[Known Issues]].

## Usage pattern

```ts
import { createClient } from 'jsr:@supabase/supabase-js@2';
const admin = createClient(SUPABASE_URL, SUPABASE_SERVICE_ROLE_KEY);
const { data, error } = await admin.from('table').select('...');
```

## Service vs anon

Most edge functions use the **service role** key for DB access (bypasses RLS). Auth-gated ones (e.g. [[newsletter-send]]) ALSO create a secondary client with the anon key + caller's JWT header to do `is_admin()` check via the caller's identity.
