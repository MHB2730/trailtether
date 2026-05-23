// Trailtether — Welcome / Onboarding pillars.
//
// Verbatim from `screens/welcome.jsx:4` (the FEATURES const). Pure
// marketing copy — lives in code because the rules treat configuration
// (vs content) as fair game.

import { tt } from '@theme/tokens';
import type { WelcomeFeature } from './types';

export const WELCOME_FEATURES: WelcomeFeature[] = [
  {
    id: 'tether',
    eyebrow: 'STAY TETHERED',
    title: 'Someone at home, always watching.',
    body:
      'Your phone broadcasts live position to a base-camp PC at home. ' +
      'No surveillance — just a tether.',
    color: tt.ember,
  },
  {
    id: 'plan',
    eyebrow: 'PLAN',
    title: 'Know what you walk into.',
    body:
      'Curated routes with distance, elevation, and live weather scored ' +
      'for hiking — not just temperature.',
    color: tt.ember2,
  },
  {
    id: 'navigate',
    eyebrow: 'NAVIGATE OFFLINE',
    title: '2D, 3D, and signal-dead.',
    body:
      'Topographic, satellite, and terrain layers. Downloaded for offline. ' +
      'Speed-coloured trail recording.',
    color: tt.ember,
  },
  {
    id: 'aware',
    eyebrow: 'STAY AWARE',
    title: 'Weather, hazards, and shelter.',
    body:
      'Multi-source forecasts, community hazard reports, 125 surveyed ' +
      'Drakensberg caves and shelters built in.',
    color: tt.amber,
  },
  {
    id: 'sos',
    eyebrow: 'ACT FAST',
    title: 'One tap. Help on the way.',
    body:
      'SOS shares your live location. Compass, flashlight, native ' +
      'emergency contacts — all one tap deep.',
    color: tt.red,
  },
];
