// Trailtether — static achievements catalog.
//
// Per BLOCKERS.md #5 the design wants a 16-tile achievement grid + a
// progress overlay for locked badges. The unlock RULES and per-user
// PROGRESS still need a server view, but the catalog itself (title /
// description / rarity / icon / unlock criterion) can ship as a static
// asset so screens render their structure today.
//
// Sourced verbatim from `screens/achievements.jsx` and
// `screens/profile.jsx` so the rarity / icon assignments match the
// design 1:1.

import type { Achievement } from './types';

/** Catalog rows lack runtime state (progress / earnedAt / unlocked). */
export interface AchievementCatalogEntry {
  id: string;
  iconName: Achievement['icon'];
  label: string;
  /** Short subtitle shown under the medallion. */
  sub: string;
  /** Longer prose shown on the LatestUnlock hero. */
  description: string;
  rarity: Achievement['rarity'];
}

export const ACHIEVEMENTS_CATALOG: AchievementCatalogEntry[] = [
  // — Common —
  {
    id: 'first',
    iconName: 'play',
    label: 'First Steps',
    sub: 'Complete 1st hike',
    description: 'Recorded your very first hike. The mountain is now part of your story.',
    rarity: 'common',
  },
  {
    id: 'gpx',
    iconName: 'route',
    label: 'Plan Maker',
    sub: 'Upload 5 GPX routes',
    description: 'Shared five GPX routes with the community.',
    rarity: 'common',
  },
  {
    id: 'rain',
    iconName: 'wind',
    label: 'Rain Dancer',
    sub: 'Hike in heavy rain',
    description: 'Completed a hike in sustained heavy rain.',
    rarity: 'common',
  },

  // — Rare —
  {
    id: 'highrise',
    iconName: 'mountain',
    label: '4K Club',
    sub: '4,000m elevation',
    description: 'Topped 4,000 metres on a single recorded hike.',
    rarity: 'rare',
  },
  {
    id: 'tether',
    iconName: 'tether',
    label: 'Tethered',
    sub: 'Pair a base-camp PC',
    description: 'Paired the app with a base-camp PC for live tethering.',
    rarity: 'rare',
  },
  {
    id: 'lead',
    iconName: 'people',
    label: 'Team Lead',
    sub: 'Lead a group hike',
    description: 'Led a group hike with at least two other tethered hikers.',
    rarity: 'rare',
  },
  {
    id: 'dawn',
    iconName: 'eye',
    label: 'Dawn Patrol',
    sub: 'Start before 05:00',
    description: 'Started a recorded hike before 05:00 local.',
    rarity: 'rare',
  },
  {
    id: 'cave',
    iconName: 'rock',
    label: 'Caver',
    sub: 'Visit 10 shelters',
    description: 'Logged visits to 10 different Drakensberg caves or shelters.',
    rarity: 'rare',
  },
  {
    id: 'navmaster',
    iconName: 'compass',
    label: 'Nav Master',
    sub: '30 trails completed',
    description: 'Completed at least 30 distinct trails end-to-end.',
    rarity: 'rare',
  },

  // — Epic —
  {
    id: 'storm',
    iconName: 'wind',
    label: 'Storm Survivor',
    sub: 'Hike through warning',
    description:
      'Completed a sustained hike through an active severe-weather warning. The mountain noticed.',
    rarity: 'epic',
  },
  {
    id: '5k',
    iconName: 'mountain',
    label: '5K Club',
    sub: '5,000m peak',
    description: 'Summited a peak above 5,000 m on a single recorded hike.',
    rarity: 'epic',
  },
  {
    id: 'centurion',
    iconName: 'route',
    label: 'Centurion',
    sub: '100 km in a month',
    description: '100 km of trail recorded within a single calendar month.',
    rarity: 'epic',
  },
  {
    id: 'winter',
    iconName: 'crosshair',
    label: 'Winter Warrior',
    sub: 'Snow-line hike',
    description: 'Completed a hike above the snow line in winter.',
    rarity: 'epic',
  },

  // — Legendary —
  {
    id: 'sos',
    iconName: 'shield',
    label: 'First Responder',
    sub: 'Help in an incident',
    description: 'Verified arrival at the scene of a community incident.',
    rarity: 'legendary',
  },
  {
    id: 'allnight',
    iconName: 'flame',
    label: 'All-Night',
    sub: 'Sleep on a peak',
    description: 'Recorded an overnight bivvy at a summit cave or shelter.',
    rarity: 'legendary',
  },
  {
    id: 'guide',
    iconName: 'people',
    label: 'Mountain Guide',
    sub: 'Lead 25 group hikes',
    description: 'Led 25 tethered group hikes as the designated lead.',
    rarity: 'legendary',
  },
];

/** O(1) lookup. */
export const ACHIEVEMENTS_BY_ID: Record<string, AchievementCatalogEntry> =
  Object.fromEntries(ACHIEVEMENTS_CATALOG.map((a) => [a.id, a]));
