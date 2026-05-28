---
tags: [type/component, layer/frontend, status/stable, domain/mobile, domain/teams]
aliases: [tt_team_screen, Teams tab]
source_paths: [trailtether_app/lib/screens/tt_team_screen.dart]
---

# TTTeamScreen

Mobile Teams tab. List of teams the user belongs to, plus per-team detail, member list, and "View Live Map" entry into [[LiveTrackingScreen]].

## Sections

- Team list (from [[team_provider.dart]] `teams`)
- Selected team detail + member chips
- "Create team" / "Join by invite code" actions ([[join_team_by_invite_code]] RPC)
- "View Live Map" → pushes [[LiveTrackingScreen]] for team-tracking view
- Per-member sheet (`_MemberDetailSheet`) — last-known position, status, distance

## Member position source

Reads [[team_member_locations]] via [[team_tracking_provider.dart]]. Shows last-update timestamp + green/grey staleness dot (45s threshold).

## Standalone team chat

Tapping the chat icon opens `_StandaloneTeamChat` (a mobile-optimised wrapper around [[chat_provider.dart]]).

## Used by

- [[AppShell]] (tab 4)

## Depends on

- [[team_provider.dart]], [[team_tracking_provider.dart]], [[chat_provider.dart]]
- [[LiveTrackingScreen]] (pushed for `_openLiveMap`)
- [[TT Design Tokens]]

## Key file

- `lib/screens/tt_team_screen.dart`
