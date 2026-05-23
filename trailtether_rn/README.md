# Trailtether — React Native (Expo)

Parallel rebuild of the Trailtether v2.0 mobile app from the official
design handoff (`.design_handoff/design_handoff_trailtether/`). Runs
alongside the production Flutter app at `../trailtether_app/` — this is
**not** a replacement, it's the implementation of the standalone RN
design package.

## Stack

- **Expo SDK 52** (React Native 0.76, new architecture enabled)
- **expo-router** v4 (file-based routes; `app/(tabs)/*` for the 6-tab
  shell, `app/*` for stack screens)
- **TypeScript** strict mode
- **react-native-svg** + **react-native-reanimated** for the design's
  heavy SVG + continuous-motion language
- **Zustand** for global app state (snow flag, future: hike, team,
  forecast, notifications, achievements per the README)
- **@expo-google-fonts/manrope** + **@expo-google-fonts/jetbrains-mono**
  — the two-font system from the handoff

## Layout

```
trailtether_rn/
├── app/                       # expo-router routes
│   ├── _layout.tsx            # font loader + Stack
│   ├── (tabs)/_layout.tsx     # 6-tab bottom nav
│   ├── (tabs)/index.tsx       # Home
│   ├── (tabs)/{map,tools,community,teams,profile}.tsx
│   └── {welcome,sign-in,trail-detail,plan-route,achievements,…}.tsx
├── src/
│   ├── theme/tokens.ts        # typed colour / type / spacing tokens
│   ├── components/
│   │   ├── Icon.tsx           # all 45 SVG icons from shared.jsx
│   │   ├── primitives/        # Card, Pill, Segmented, AppBar, …
│   │   └── medallion/         # Achievement hex medallion (TBD)
│   └── store/app.ts           # Zustand global state
└── assets/                    # fonts + hero images + logo
```

## Implementation order (from the handoff README)

1. ✅ Design tokens — `src/theme/tokens.ts`
2. ✅ Icon component — `src/components/Icon.tsx`
3. ✅ App shell + 6-tab nav — `app/_layout.tsx`, `app/(tabs)/_layout.tsx`
4. ✅ Card / Pill / Segmented primitives — `src/components/primitives/*`
5. 🛠 Home — `app/(tabs)/index.tsx` (structural pass shipped, animations + Field Intel feed pending)
6. ⬜ Profile + Achievements hex medallion
7. ⬜ Trails list + Trail Detail (Interactive Explorer)
8. ⬜ Other tabs — Map, Tools, Community, Teams
9. ⬜ Safety + SOS
10. ⬜ Utility screens — Settings, Notifications, Search, Edit Profile, …

## Running

```sh
cd trailtether_rn
npm install
npx expo start
```

Then press `a` to open the Android emulator (or scan the QR code with
Expo Go on a real device).
