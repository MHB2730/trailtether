// Trailtether — global app state.
//
// Zustand was picked over Redux per the README's "Redux Toolkit or Zustand"
// recommendation — Zustand gives us a smaller surface for this prototype
// build and we can swap to RTK later if the slice count grows.
//
// What lives here:
//   * `snow` — the snow-easter-egg flag. The handoff `useTT()` hook in
//     `screens/shared.jsx` exposes this so the Tweaks panel can flip it
//     manually. In a real build a forecast service polls Drakensberg snowfall
//     and toggles this when any of the next 7 days predicts snowfall above
//     1,800m.
//   * Future: current user, active hike, team membership, forecast cache,
//     notifications feed, offline-map cache, achievements progress
//     (per the README "Global state needed at app level" list).

import { create } from 'zustand';

export interface AppState {
  snow: boolean;
  setSnow: (v: boolean) => void;
}

export const useApp = create<AppState>((set) => ({
  snow: false,
  setSnow: (v) => set({ snow: v }),
}));
