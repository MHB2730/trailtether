# TrailTether — Hardening Audit Log

**Date:** 2026-05-30
**Auditor:** Claude (Opus 4.8, 1M ctx) — autonomous pipeline
**Repo:** `C:\Users\bremn\Documents\Trailtetherv2.0`
**Vault:** `docs/`
**Supabase target:** PRODUCTION (`xuqmdujupbmxahyhkdwl`) — back up first, forward-only, SQL shown before apply.
**Git target:** `main` (direct, per GATE-C)
**Gates:** E=list-only (no history rewrite) · F=rotate-DB-reachable+list-rest · G=unsigned Flutter (flag signing) · H=Garmin key present · I=webhook code-audit only (secrets unreadable) · J=distribution gated.

> Note: a security pass earlier the same day already landed the Supabase RLS/grant/verify_jwt
> hardening (migration `20260530_security_audit_critical_high_fixes`, 9 edge-function redeploys,
> `20260530_reviews_teamstats_intent`). This audit VERIFIES those held and goes deep on the
> components that hadn't had a pass: Flutter app, admin SPA, storefront, Garmin watch, payment
> webhook code, and the safety-critical location/off-trail/weather logic.

---

## Severity legend
- **CRITICAL** — active data-leak / breach / safety-misleading path. Fix immediately.
- **HIGH** — one step from a breach, or a real correctness/safety bug.
- **MEDIUM** — defense-in-depth gap or non-safety bug.
- **LOW** — cosmetic / docs / nice-to-have.

---

## Method note
Six parallel read-only audit agents swept vault, safety logic, Flutter, Supabase,
payments+admin+site, and git-history. **Every CRITICAL/HIGH agent claim was then
verified against ground truth before any action** — and ~5 of 8 were FALSE ALARMS
(agents not accounting for release-mode gating, gitignore, in-body `is_admin`
guards, and empty buckets). Only verified findings appear below.

## Findings (VERIFIED)

### CRITICAL
- **None.** No service-role key leak, no committed secrets, no RLS bypass, no
  payment-forgery path, safety logic fails safe throughout.

### HIGH
- **H1 — Auth leaked-password protection still disabled.** `auth_leaked_password_protection=false`.
  Pending since v4. Enable in Dashboard → Authentication → Password (HaveIBeenPwned).
  Not in tool reach (PAT revoked). **Action: user, 1 toggle.**

### MEDIUM
- **M1 — `incident-photos` storage bucket is public.** `incident_service.uploadPhoto`
  writes safety-incident photos to a `public:true` bucket and serves via
  `getPublicUrl` (`incident_service.dart:78,83`). Bucket is **empty today (0 objects)**
  so no live leak, but once used, incident photos are world-readable-by-URL
  (path `<uid>/<millis>-<name>` is unguessable but permanent). Proper fix is a
  coordinated change: switch incident-photo display to `createSignedUrl` then flip
  the bucket private. **Flagged, not blind-flipped** (would break image display).
- **M2 — `watch_devices` has no owner DELETE policy.** A user can read their paired
  watches (SELECT) but cannot self-revoke a lost/stolen watch's token from the
  client (no revoke RPC either). Not a leak; a missing capability. **Fix staged in
  the gated migration below (additive, safe).**
- **M3 — Zapper webhook multi-format signature fallback.** `zapper-webhook` accepts
  4 candidate header names × {hex, base64}; marked UNCONFIRMED in code. Widens the
  accept surface. Tightening blind risks breaking the real Zapper format. **Flag:
  confirm the canonical header+encoding against a real delivery, then narrow.** Do
  NOT change before confirmation (live-payment risk).

### LOW
- **L1 — Bucket sprawl.** `gpx-files` + `gpx_files` are empty, unused, `public:true`
  buckets. Candidates for deletion (gated — needs an explicit yes on prod).
- **L2 — Dead code in `pc_shell.dart`** (2 unused private classes + 1 unused import).
  **FIXED this pass.**
- **L3 — Watch dev token default in `properties.xml`.** Known + intentional +
  documented; clear before Connect IQ Store publish. Already in vault DO-NOT-TOUCH.
- **L4 — `tether_pairings` hiker can't self-revoke** a pairing watching them (only
  the watcher/owner can). Product decision, not a hole.

### Payment-webhook verification status (code audit; secrets unreadable — GATE-I)
| Gateway | Sig-before-mutation | Amount vs DB | Replay/idempotent | Fails closed | verify_jwt | Verdict |
|---|---|---|---|---|---|---|
| PayFast ITN | ✓ | ✓ (±0.01) | ✓ | ✓ | false ✓ | **PASS** |
| Yoco | ✓ | ✓ (cents ==) | ✓ (+5min window) | ✓ | false ✓ | **PASS** |
| Zapper | ✓ | ✓ | ✓ | ✓ | false ✓ | **PASS, but M3** |
_None could be executed end-to-end (signing secrets are server-side env vars, not readable)._

### Safety-critical logic (Phase 2) — audited deep, NO changes needed
All paths verified to FAIL SAFE; no safety behaviour was altered (so no safety-test
obligations triggered):
- Off-trail: threshold `40m + 1.5×accuracy, cap 120m` (`recording_provider.dart`),
  5-min debounce, 1 incident/5min, offline-queued, bearing guidance, clears on
  no-route. Fails safe (warns, doesn't silently say "on trail").
- Live tracking: position age graded `isLive ≤30s / isRecent ≤5m / isStale >5m`
  (`team.dart`) — **the "headline bug" (stale shown as live) is handled**; watchers
  see age. Ghost-mode + offline queue sound.
- SOS: 5s hold + 15s insert timeout + LOUD failure (red retry snackbar); guards
  null GPS twice and refuses to fire without a fix (`sos_screen.dart:107-116`).
- Weather: 45-min lead-time gate, severity thresholds, dedupes, no-spam on fetch fail.
- GPS pipeline: accuracy ≤30 accept / >100 reject / adaptive middle, jump >10m/s
  reject, monotonic-time enforced, UTC timestamps, metres throughout.
- Watch off-route: `nearestRouteDistM` returns −1 sentinel when no/`(0,0)` route →
  OFF ROUTE never false-fires; 50m threshold advisory only.

### FALSE ALARMS (verified — reported for honesty, no action)
- "Committed keystore passwords (key.properties)" — gitignored, untracked, not in history.
- "INSERT policies missing WITH CHECK (hike_history, team_member_track_points)" — both have correct WITH CHECK.
- "admin_* callable by authenticated w/o checks" — all gate `is_admin()` + RAISE in-body.
- "CRITICAL: storage enumerate all photos/trails" — sensitive buckets (recorded-trails, gpx_uploads) are private; public ones empty or avatars (intentional).
- "CRITICAL: PII GPS remote-logging in production" — `_remoteLoggingEnabled` defaults to `kDebugMode` (off in release).
- "SOS proceeds with null position" — guards null + shows error, never fires without GPS.

## Gated migration (PRODUCTION — awaiting explicit yes per GATE-D)
```sql
-- M2: let a user revoke their own paired watch (lost/stolen device).
-- Additive, owner-scoped, no data touched.
CREATE POLICY watch_devices_owner_delete ON public.watch_devices
  FOR DELETE TO authenticated
  USING (auth.uid() = user_id);
```

## Backlog (from vault TODOs + this audit)
- Enable Auth leaked-password protection (H1).
- Incident-photos → signed URLs + private bucket (M1).
- Confirm Zapper signature scheme, then narrow (M3).
- Delete empty `gpx-files`/`gpx_files` buckets (L1).
- Clear watch `properties.xml` default token before CIQ Store publish (L3).
- (vault) Commit `supabase/config.toml` pinning verify_jwt=false for webhooks.
- (vault) Migrations folder incomplete — can't bootstrap fresh project from repo alone; needs a live schema dump committed.
- (vault) On-device QA of core flows still pending (sign-up, team, record+save, live-PC).

## Fixes applied
- `audit/hardening` work committed to `main` (see git log): deep-link auth-payload
  guard (`deep_link_service.dart`), dead-code removal (`pc_shell.dart`). `flutter
  analyze` → 0 issues.
