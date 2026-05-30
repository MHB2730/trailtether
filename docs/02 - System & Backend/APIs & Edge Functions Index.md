---
type: index
status: current
area: backend
aliases:
  - API Index
  - Edge Functions Index
---

# APIs & Edge Functions Index

All 15 deployed Deno edge functions live in `supabase/functions/`. See [[Supabase Functions Module]] for architecture, auth patterns, and deploy instructions.

## Payments

| Function | Auth | Role |
|---|---|---|
| [[payfast-checkout]] | JWT | Generate PayFast redirect URL (md5 signature) |
| [[payfast-itn]] | Signature (no JWT) | PayFast ITN webhook handler |
| [[yoco-checkout]] | JWT | Create Yoco hosted checkout |
| [[yoco-webhook]] | HMAC (no JWT) | Yoco notification handler |
| [[zapper-checkout]] | JWT | Create Zapper invoice deeplink |
| [[zapper-webhook]] | HMAC (no JWT) | Zapper notification handler |

## Newsletter and Subscribers

| Function | Auth | Role |
|---|---|---|
| [[subscriber-send-confirmation]] | None (anon, validates token) | Send subscriber confirm email |
| [[newsletter-send]] | JWT + is_admin | Admin newsletter blaster |
| [[newsletter-track-open]] | None (public pixel) | Open tracking pixel |
| [[newsletter-track-click]] | None (public redirect) | 302-redirect with click record |

## Supabase Postgres RPCs (not edge functions — called via `supabase.rpc()`)

| RPC | Defined in | Role |
|---|---|---|
| `subscriber_signup` | Pre-migration | Sign up for newsletter |
| `subscriber_confirm` | Pre-migration | Confirm subscription |
| `subscriber_unsubscribe` | Pre-migration | Unsubscribe |
| [[newsletter_segment_count]] | Pre-migration | Count subscribers for a segment |
| [[is_admin]] | Pre-migration | Check admin status |
| [[join_team_by_invite_code]] | Pre-migration | Join team by code |
| [[team_add_member]] | Pre-migration | Add member to team |
| [[team_remove_member]] | Pre-migration | Remove member from team |
| [[verify_incident]] | Pre-migration | Vote to verify hazard |
| [[flag_incident]] | Pre-migration | Flag hazard for moderation |
| [[ping_safety_plan]] | Pre-migration | Ping emergency contact for safety check-in |
| [[claim_tether_token]] | Pre-migration | Claim PC↔mobile pairing token |
| [[mint_watch_token]] | Pre-migration | Issue Garmin watch pairing token |
| [[set_watch_active_route]] | Pre-migration | Push planned route to the watch |
| [[list_watch_devices]] | Pre-migration | List paired watches + last_seen + active route (Profile status) |
| [[mark_notification_read]] | Pre-migration | Mark notification read |
| [[handle_new_user]] | Pre-migration | Auto-create profile on signup (trigger) |
| [[place_order]] | `20260524_phase_b_orders.sql` | Create merch order |
| [[get_order_for_confirmation]] | `20260524_phase_b_orders.sql` | Fetch order for receipt page |
| [[admin_trailtether_stats]] | `20260526_admin_trailtether_rpcs.sql` | Admin dashboard stats |
| [[admin_trailtether_active_users]] | `20260526_admin_trailtether_rpcs.sql` | Active user list |
| [[admin_trailtether_recent_hikes]] | `20260526_admin_trailtether_rpcs.sql` | Recent hike list |
| [[admin_trailtether_teams]] | `20260526_admin_trailtether_rpcs.sql` | Team list for admin |
| [[admin_trailtether_top_hikers]] | `20260526_admin_trailtether_rpcs.sql` | Top hikers leaderboard |
| [[berg_pulse_stats]] | `20260527_berg_live_views_rpcs.sql` | Berg Live community totals |
| [[berg_pulse_leaderboard]] | `20260527_berg_live_views_rpcs.sql` | Berg Live team leaderboard |
| `berg_pulse_active_count` | `20260527_berg_live_views_rpcs.sql` | Count active Berg hikers |
| `berg_pulse_heatmap_cells` | `20260527_berg_live_views_rpcs.sql` | Hex-binned heatmap cells for `/pulse/` |
| `admin_set_team_public` | `20260527_berg_live_admin_kill_switch.sql` | Admin toggle team public visibility |
| `increment_recorded_trail_downloads` | `20260528_recorded_trail_downloads_rpc.sql` | Increment download counter |
| `profiles_public` | `20260526_profiles_pii_lockdown.sql` | POPIA-safe public profile view |
| [[app_release_meta]] | Pre-migration | Latest APK version + download URL |

## App and Ops (edge functions)

| Function | Auth | Role |
|---|---|---|
| [[analytics-ingest]] | None (POPIA-safe beacon) | Site analytics ingestion |
| [[apk-download-gate]] | None (Turnstile gate) | Gated APK download |
| [[publish-site]] | JWT + is_admin | cPanel UAPI site publisher |
| [[health-pinger]] | Cron secret | pg_cron uptime checker |
| [[finalize-orphan-hikes]] | Cron secret | Recover unsaved hike sessions |
| [[watch-ingest]] | x-device-token | Garmin watch hike upload (writes hike_history + recorded_trails + GPX) |
| [[watch-route]] | x-device-token | Garmin watch route picker + by-id course fetch |

## Related

- [[Supabase Functions Module]] — architecture + common patterns
- [[Supabase Migrations Module]] — where RPCs are defined
- [[Workflow - Checkout]]
- [[Workflow - Newsletter]]
- [[Workflow - Live Team Tracking]]
