---
tags: [type/module, layer/frontend, status/stable, domain/ui]
aliases: [Screens]
source_paths: [trailtether_app/lib/screens]
---

# Flutter Screens Module

Page-level UI. 32 screen files across `lib/screens/` and its sub-folders.

## Two shells, two UX

| Shell | Platform | File |
|---|---|---|
| [[AppShell]] | Mobile (Android) | `lib/screens/app_shell.dart` |
| [[MainPcShell]] | Desktop (Windows / macOS / Linux) | `lib/screens/pc/pc_shell.dart` |

Branching happens in [[AuthGate]]: onboarding check first, then `MediaQuery.size.width > 900` → desktop, else mobile.

---

## Auth + onboarding flow

| Screen | File | Role |
|---|---|---|
| [[AuthGate]] | `auth_gate.dart` | Root router — checks onboarding, auth session, screen size |
| TTWelcomeScreen | `tt_welcome_screen.dart` | New user onboarding/welcome (replaces old `welcome_screen.dart`) |
| OnboardingScreen | `onboarding_screen.dart` | Legacy POPIA consent gate; `hasCompletedOnboarding()` / `markOnboardingDone()` helpers live here |
| LoginScreen | `login_screen.dart` | Google sign-in prompt (shown when `session == null`) |
| PrivacyPolicyScreen | `privacy_policy_screen.dart` | In-app privacy policy viewer |

---

## Mobile screens (under [[AppShell]] — 6 tabs)

AppShell uses `_LazyTabStack` — tabs are kept alive once first visited, using `Offstage`.

| Tab index | Screen | File |
|---|---|---|
| 0 | [[TTHomeScreen]] | `tt_home_screen.dart` |
| 1 | [[TTMapScreen]] | `tt_map_screen.dart` |
| 2 | TTToolsScreen | `tt_tools_screen.dart` |
| 3 | TTCommunityScreen | `tt_community_screen.dart` |
| 4 | TTTeamScreen | `tt_team_screen.dart` |
| 5 | [[TTProfileScreen]] | `tt_profile_screen.dart` |

**Bottom nav:** `widgets/design/tt_bottom_nav.dart` (`TTBottomNav`).

---

## Secondary mobile screens (pushed via Navigator)

| Screen | File | Notes |
|---|---|---|
| TTActivityScreen | `tt_activity_screen.dart` | Activity / workout feed |
| [[LiveTrackingScreen]] | `live_tracking_screen.dart` | Full-screen recording UI; also entry point from Teams "View Live Map" |
| RecordedTrailsScreen | `recorded_trails_screen.dart` | User's shareable recorded trails |
| HikeHistoryScreen | `hike_history_screen.dart` | Past hike log |
| CreateHikePlanScreen | `create_hike_plan_screen.dart` | Plan builder |
| HikePlanDetailScreen | `hike_plan_detail_screen.dart` | Plan viewer/editor |
| TrailDetailScreen | `trail_detail_screen.dart` | Trail info + map preview |
| [[TeamDetailScreen]] | `team_detail_screen.dart` | Team stats + members |
| TeamChatScreen | `team_chat_screen.dart` | Team realtime chat (was `chat_screen.dart`) |
| CreateTeamScreen | `create_team_screen.dart` | New team form |
| JoinTeamScreen | `join_team_screen.dart` | Join by invite code |
| TeamInviteScreen | `team_invite_screen.dart` | Share invite link / QR |
| ReviewsScreen | `reviews_screen.dart` | Trail reviews list |
| ProfileTab | `profile_tab.dart` | Legacy profile view (check if still routed; `tt_profile_screen.dart` is primary) |
| SafetyCenterScreen | `safety_center_screen.dart` | Safety plan + emergency contacts hub |
| SOSScreen | `sos_screen.dart` | SOS emergency trigger |

---

## Desktop screens (under [[MainPcShell]])

Each is a `_PcSection` enum tag, dispatched in `_PcContent`:

| Section | Content | File |
|---|---|---|
| dashboard | [[MissionControlTab]] | `screens/admin/mission_control_tab.dart` |
| watch | `_PcHikeWatch` (private) | `screens/pc/pc_shell.dart` |
| hikers | `_PcHikersList` (private) | `screens/pc/pc_shell.dart` |
| history | `_PcHistory` (private) | `screens/pc/pc_shell.dart` |
| **trails** | [[PcTrailsScreen]] (admin-only) | `screens/pc/pc_trails_screen.dart` |
| alerts | `_PcAlerts` (private) | `screens/pc/pc_shell.dart` |
| pair | `PcPairDeviceScreen` | `screens/pc/pc_shell.dart` |
| **settings** | [[AdminSettingsTab]] (admin-only) | `screens/admin/admin_settings_tab.dart` |

Admin-only sections filtered by `AuthProvider.isAdmin` — see [[Workflow - Auth]] and the `adminOnly` flag in `_NavSpec`.

---

## Recording UX surfaces

- [[StartHikeRamp]] — slide-to-start + 3-2-1 countdown. Returns `true` from `show()` on confirm. (`widgets/start_hike_ramp.dart`)
- [[FinishHikeSheet]] — Strava-style Save / Discard / Resume. Called from [[TTMapScreen]] (STOP) and [[LiveTrackingScreen]] (FINISH). (`widgets/finish_hike_sheet.dart`)
- [[LiveTrackingScreen]] — full-screen recording fallback with compass.
- [[TTMapScreen]] — primary recording UI with live stats bottom sheet.

---

## Depends on

- [[Flutter Providers Module]] — `context.watch<X>()` everywhere
- [[Flutter Widgets Module]] — every screen composes design primitives
- [[Flutter Services Module]] — direct service calls for one-off ops
- [[TT Design Tokens]] — `TT.*` token class (`design_tokens.dart`)

## Used by

- [[AuthGate]] dispatches to one of [[AppShell]] / [[MainPcShell]]
- Some screens push other screens via `Navigator.push` / `Navigator.pushNamed`
