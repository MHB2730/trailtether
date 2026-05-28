---
tags: [type/dep, layer/backend, status/stable, domain/email]
aliases: [denomailer]
source_paths: [supabase/functions/newsletter-send/index.ts, supabase/functions/subscriber-send-confirmation/index.ts]
---

# denomailer

`https://deno.land/x/denomailer@1.6.0/mod.ts`

SMTP client for Deno. The edge functions use this to send email (no third-party email provider).

## Usage

```ts
import { SMTPClient } from "https://deno.land/x/denomailer@1.6.0/mod.ts";

const client = new SMTPClient({
  connection: {
    hostname: SMTP_HOST,
    port: SMTP_PORT,           // 465 typically
    tls: true,
    auth: { username: SMTP_USER, password: SMTP_PASS },
  },
});

await client.send({
  from: `${FROM_NAME} <${FROM_EMAIL}>`,
  to: email,
  subject: '...',
  content: text,
  html: html,
});

await client.close();
```

## Used by

- [[subscriber-send-confirmation]]
- [[newsletter-send]]

## Env vars

`SMTP_HOST`, `SMTP_PORT`, `SMTP_USER`, `SMTP_PASS` set in [[Edge Function Secrets]].

## Note: one connection per blast

[[newsletter-send]] reuses one `SMTPClient` for all recipients in a batch (vs. opening a fresh connection per email). Reasonable for hundreds-of-recipients lists; would need batching for thousands.
