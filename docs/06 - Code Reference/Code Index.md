---
type: index
status: current
area: code
aliases:
  - Code Index
  - Generated Code Index
---

# Code Index

Code-adjacent reference notes. Keep them factual and source-linked. Product intent belongs in [[Product & Strategy Index]]; architecture decisions belong in [[Architecture Index]].

## Screens and Shells (Components)

### Auth and onboarding

- [[AuthGate]] — root router
- `LoginScreen` — `login_screen.dart`
- `TTWelcomeScreen` — `tt_welcome_screen.dart`
- `OnboardingScreen` — `onboarding_screen.dart`
- `PrivacyPolicyScreen` — `privacy_policy_screen.dart`

### Mobile shells and primary tabs

- [[AppShell]] — 6-tab mobile shell
- [[TTHomeScreen]]
- [[TTMapScreen]]
- `TTToolsScreen` — `tt_tools_screen.dart`
- `TTCommunityScreen` — `tt_community_screen.dart`
- `TTTeamScreen` — `tt_team_screen.dart`
- [[TTProfileScreen]]

### Secondary mobile screens

- `TTActivityScreen` — `tt_activity_screen.dart`
- [[LiveTrackingScreen]]
- `RecordedTrailsScreen` — `recorded_trails_screen.dart`
- `HikeHistoryScreen` — `hike_history_screen.dart`
- `CreateHikePlanScreen` — `create_hike_plan_screen.dart`
- `HikePlanDetailScreen` — `hike_plan_detail_screen.dart`
- `TrailDetailScreen` — [[TrailDetailScreen]]
- [[TeamDetailScreen]]
- `TeamChatScreen` — `team_chat_screen.dart`
- `CreateTeamScreen` — `create_team_screen.dart`
- `JoinTeamScreen` — `join_team_screen.dart`
- `TeamInviteScreen` — `team_invite_screen.dart`
- `ReviewsScreen` — `reviews_screen.dart`
- `SafetyCenterScreen` — `safety_center_screen.dart`
- `SOSScreen` — `sos_screen.dart`

### Desktop shell and sections

- [[MainPcShell]]
- [[MissionControlTab]]
- [[PcTrailsScreen]]
- [[AdminSettingsTab]]

### Recording UX

- [[StartHikeRamp]]
- [[FinishHikeSheet]]

### Shared detail sheets (widgets)

- [[IncidentDetailSheet]]
- [[CaveDetailSheet]]
- `FieldIntelSheet` — `widgets/field_intel_sheet.dart`
- `AccommodationDetailSheet` — `widgets/accommodation_detail_sheet.dart`

## Map and Design Widgets

- [[TrailMapWidget]]
- [[TrailMap3DWidget]]
- [[TrailMarkerLayer]]
- [[SpeedPathLayer]]
- [[TT Design Tokens]]
- `TTGlassCard` — `widgets/design/tt_glass_card.dart`
- [[TTPill]]
- `TTAppBar` — `widgets/design/tt_app_bar.dart` (was TTPageAppBar)
- `TTBottomNav` — `widgets/design/tt_bottom_nav.dart`
- `UpdateBanner` — `widgets/update_banner.dart`

## Dependencies

- [[External Dependencies]]
- [[supabase_flutter]]
- [[supabase-js]]
- [[flutter_map]]
- [[geolocator]]
- [[provider]]
- [[fl_chart]]
- [[gpx]]
- [[webview_flutter]]
- [[app_links]]
- [[flutter_local_notifications]]
- [[denomailer]]

## Source File Stubs

Source-file stubs live in `06 - Code Reference/Source Files`. Key stubs:

**Providers:** [[auth_provider.dart]], [[recording_provider.dart]], [[team_tracking_provider.dart]], [[safety_provider.dart]], [[static_data_provider.dart]], [[weather_provider.dart]], [[chat_provider.dart]], [[community_provider.dart]], [[team_provider.dart]], [[profile_provider.dart]]

**Services:** [[trail_service.dart]], [[location_service.dart]], [[logger_service.dart]], [[weather_service.dart]], [[incident_service.dart]], [[update_service.dart]], [[offline_track_queue.dart]], [[offline_incident_queue.dart]], [[offline_map_service.dart]], [[deep_link_service.dart]], [[telemetry_service.dart]], [[health_connect_service.dart]], [[local_map_server.dart]], [[auth_service.dart]], [[chat_service.dart]], [[community_service.dart]], [[device_service.dart]], [[team_service.dart]], [[weather_aggregator_service.dart]]

**Site / scripts:** [[site.js]], [[cart.js]], [[analytics.js]], [[weather.js]], [[subscribe.js]], [[publish_release.ps1]], [[publish_site.ps1]], [[publish_windows.ps1]]

## Related

- [[App Modules Index]]
- [[Data & Supabase Index]]
- [[APIs & Edge Functions Index]]
