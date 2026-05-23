// Trailtether — static rescue service directory.
//
// The "rescue" / "ambulance" rows that appear at the top of the
// Safety Center's emergency contacts list. Static because these are
// regional public-service numbers, not per-user data. Sourced from the
// existing Flutter app's safety_center screen.

import type { EmergencyContact } from './types';

export const RESCUE_SERVICES_DRAKENSBERG: EmergencyContact[] = [
  {
    id: 'msar-drakensberg',
    name: 'MSAR · Mountain Rescue',
    sub: '24/7 · Drakensberg',
    phone: '074 125 1385',
    type: 'rescue',
  },
  {
    id: 'er24',
    name: 'National Emergency',
    sub: 'ER24 · ambulance',
    phone: '084 124',
    type: 'ambulance',
  },
];
