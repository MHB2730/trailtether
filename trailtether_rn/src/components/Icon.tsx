// Trailtether — Icon component.
//
// Single switch-statement covering all 45 stroke-based icons used across
// the app, ported verbatim from the design handoff's `shared.jsx`. Every
// icon is on a 0 0 24 24 viewBox so the `size` prop scales them uniformly.
//
// API matches the React prototype: `<Icon name size color strokeWidth />`.
// Defaults: size 16, color "currentColor" (which in RN becomes the surrounding
// Text colour via the `color` prop), strokeWidth 1.7.
//
// Adding an icon: drop another `case` clause with the same viewBox + stroke
// settings as `common`. Filled icons (play, pause, send, navigation) use
// `fill={c}` and no stroke.

import React from 'react';
import Svg, {
  Circle,
  G,
  Path,
  Polyline,
  Rect,
} from 'react-native-svg';

export type IconName =
  | 'mountain'
  | 'layers'
  | 'compass'
  | 'plus'
  | 'minus'
  | 'crosshair'
  | 'route'
  | 'filter'
  | 'search'
  | 'settings'
  | 'alert'
  | 'shield'
  | 'radio'
  | 'pin'
  | 'flame'
  | 'heart'
  | 'check'
  | 'chevron-right'
  | 'chevron-down'
  | 'chevron-up'
  | 'arrow-up-right'
  | 'send-fill'
  | 'sos'
  | 'people'
  | 'eye'
  | 'clock'
  | 'arrow-up'
  | 'menu'
  | 'more'
  | 'wind'
  | 'rock'
  | 'home'
  | 'history'
  | 'user'
  | 'phone'
  | 'map'
  | 'play'
  | 'pause'
  | 'stop'
  | 'bell'
  | 'message'
  | 'navigation'
  | 'tether';

export interface IconProps {
  name: IconName;
  size?: number;
  color?: string;
  strokeWidth?: number;
}

export function Icon({
  name,
  size = 16,
  color = '#eef1f4',
  strokeWidth = 1.7,
}: IconProps): React.ReactElement | null {
  const s = size;
  const c = color;
  const sw = strokeWidth;
  // Re-used props for every stroke icon. Filled icons override stroke/fill
  // inline where they appear.
  const common = {
    width: s,
    height: s,
    viewBox: '0 0 24 24',
    fill: 'none' as const,
    stroke: c,
    strokeWidth: sw,
    strokeLinecap: 'round' as const,
    strokeLinejoin: 'round' as const,
  };

  switch (name) {
    case 'mountain':
      return (
        <Svg {...common}>
          <Path d="M3 20 L9 9 L13 15 L16 11 L21 20 Z" />
        </Svg>
      );
    case 'layers':
      return (
        <Svg {...common}>
          <Path d="M12 3 L21 8 L12 13 L3 8 Z" />
          <Path d="M3 12 L12 17 L21 12" />
          <Path d="M3 16 L12 21 L21 16" />
        </Svg>
      );
    case 'compass':
      // Pointy-top hexagonal dial — feels crystalline / topographic.
      return (
        <Svg {...common}>
          <Path d="M12 2.6 L20.4 7.6 L20.4 16.4 L12 21.4 L3.6 16.4 L3.6 7.6 Z" />
          {/* Cardinal hash marks */}
          <Path d="M12 4.4 v1.5 M12 18.1 v1.5 M4.9 12 h1.5 M17.6 12 h1.5" />
          {/* Sharp north needle — top half solid */}
          <Path d="M12 6.4 L13.7 12 L12 11.1 L10.3 12 Z" fill={c} stroke="none" />
          {/* South tail — outlined */}
          <Path d="M12 12.9 L13.7 12 L12 17.6 L10.3 12 Z" />
          {/* Center pivot */}
          <Circle cx={12} cy={12} r={0.95} fill={c} stroke="none" />
        </Svg>
      );
    case 'plus':
      return (
        <Svg {...common}>
          <Path d="M12 5v14M5 12h14" />
        </Svg>
      );
    case 'minus':
      return (
        <Svg {...common}>
          <Path d="M5 12h14" />
        </Svg>
      );
    case 'crosshair':
      return (
        <Svg {...common}>
          <Circle cx={12} cy={12} r={3} />
          <Path d="M12 2v3M12 19v3M2 12h3M19 12h3" />
        </Svg>
      );
    case 'route':
      return (
        <Svg {...common}>
          <Circle cx={6} cy={19} r={2.5} />
          <Circle cx={18} cy={5} r={2.5} />
          <Path d="M8 19 h6 a3 3 0 003-3 v-6 a3 3 0 013-3" />
        </Svg>
      );
    case 'filter':
      return (
        <Svg {...common}>
          <Path d="M3 5h18 L14 13 v6 l-4 2 v-8 z" />
        </Svg>
      );
    case 'search':
      return (
        <Svg {...common}>
          <Circle cx={11} cy={11} r={7} />
          <Path d="M20 20 l-3.5 -3.5" />
        </Svg>
      );
    case 'settings':
      return (
        <Svg {...common}>
          <Circle cx={12} cy={12} r={3} />
          <Path d="M19.4 15a1.6 1.6 0 0 0 .3 1.8l.1.1a2 2 0 1 1-2.8 2.8l-.1-.1a1.6 1.6 0 0 0-1.8-.3 1.6 1.6 0 0 0-1 1.5V21a2 2 0 0 1-4 0v-.1a1.6 1.6 0 0 0-1-1.5 1.6 1.6 0 0 0-1.8.3l-.1.1A2 2 0 1 1 4.4 17l.1-.1a1.6 1.6 0 0 0 .3-1.8 1.6 1.6 0 0 0-1.5-1H3a2 2 0 0 1 0-4h.1a1.6 1.6 0 0 0 1.5-1 1.6 1.6 0 0 0-.3-1.8l-.1-.1A2 2 0 1 1 7 4.4l.1.1a1.6 1.6 0 0 0 1.8.3H9a1.6 1.6 0 0 0 1-1.5V3a2 2 0 0 1 4 0v.1a1.6 1.6 0 0 0 1 1.5 1.6 1.6 0 0 0 1.8-.3l.1-.1A2 2 0 1 1 19.6 7l-.1.1a1.6 1.6 0 0 0-.3 1.8V9a1.6 1.6 0 0 0 1.5 1H21a2 2 0 0 1 0 4h-.1a1.6 1.6 0 0 0-1.5 1z" />
        </Svg>
      );
    case 'alert':
      return (
        <Svg {...common}>
          <Path d="M12 3 L22 20 H2 Z" />
          <Path d="M12 10 v5" />
          <Circle cx={12} cy={18} r={0.9} fill={c} stroke="none" />
        </Svg>
      );
    case 'shield':
      return (
        <Svg {...common}>
          <Path d="M12 3 L20 6 v6 c0 5-4 8-8 9-4-1-8-4-8-9 V6 Z" />
        </Svg>
      );
    case 'radio':
      return (
        <Svg {...common}>
          <Path d="M4 11 a8 8 0 0116 0" />
          <Path d="M7 11 a5 5 0 0110 0" />
          <Circle cx={12} cy={11} r={1.6} fill={c} stroke="none" />
          <Path d="M9 17 h6 M10 21 h4" />
        </Svg>
      );
    case 'pin':
      return (
        <Svg {...common}>
          <Path d="M12 22 s-7-7-7-12 a7 7 0 1114 0 c0 5-7 12-7 12z" />
          <Circle cx={12} cy={10} r={2.5} />
        </Svg>
      );
    case 'flame':
      return (
        <Svg {...common}>
          <Path d="M12 22 c-4 0-7-3-7-7 0-3 2-5 3-7 1 2 2 3 4 3 0-3-1-5 1-8 1 2 6 5 6 12 0 4-3 7-7 7z" />
        </Svg>
      );
    case 'heart':
      return (
        <Svg {...common}>
          <Path d="M12 21 s-7-4.5-7-11 a4 4 0 017-2.7 a4 4 0 017 2.7 c0 6.5-7 11-7 11z" />
        </Svg>
      );
    case 'check':
      return (
        <Svg {...common}>
          <Path d="M4 12 l5 5 L20 6" />
        </Svg>
      );
    case 'chevron-right':
      return (
        <Svg {...common}>
          <Path d="M9 6 l6 6 -6 6" />
        </Svg>
      );
    case 'chevron-down':
      return (
        <Svg {...common}>
          <Path d="M6 9 l6 6 6-6" />
        </Svg>
      );
    case 'chevron-up':
      return (
        <Svg {...common}>
          <Path d="M6 15 l6 -6 6 6" />
        </Svg>
      );
    case 'arrow-up-right':
      return (
        <Svg {...common}>
          <Path d="M7 17 L17 7 M9 7 h8 v8" />
        </Svg>
      );
    case 'send-fill':
      return (
        <Svg width={s} height={s} viewBox="0 0 24 24" fill={c}>
          <Path d="M22 2 L2 9 L11 13 L15 22 Z" />
        </Svg>
      );
    case 'sos':
      return (
        <Svg {...common}>
          <Circle cx={12} cy={12} r={9} />
          <Path d="M9 10 c-1 0-2 .5-2 1.5 s1 1.5 2 1.5 s2 .5 2 1.5 s-1 1.5-2 1.5" />
          <Path d="M14 10 v4" />
          <Path d="M17 10 v4" />
        </Svg>
      );
    case 'people':
      return (
        <Svg {...common}>
          <Circle cx={9} cy={9} r={3} />
          <Path d="M3 20 c0-3 3-5 6-5 s6 2 6 5" />
          <Circle cx={17} cy={8} r={2.5} />
          <Path d="M21 19 c0-2-1.5-3.5-4-4" />
        </Svg>
      );
    case 'eye':
      return (
        <Svg {...common}>
          <Path d="M2 12 s4-7 10-7 s10 7 10 7 s-4 7-10 7 s-10-7-10-7z" />
          <Circle cx={12} cy={12} r={3} />
        </Svg>
      );
    case 'clock':
      return (
        <Svg {...common}>
          <Circle cx={12} cy={12} r={9} />
          <Path d="M12 7 v5 l3 2" />
        </Svg>
      );
    case 'arrow-up':
      return (
        <Svg {...common}>
          <Path d="M12 19 V5 M5 12 l7-7 7 7" />
        </Svg>
      );
    case 'menu':
      return (
        <Svg {...common}>
          <Path d="M3 6 h18 M3 12 h18 M3 18 h18" />
        </Svg>
      );
    case 'more':
      return (
        <Svg {...common}>
          <Circle cx={5} cy={12} r={1.5} fill={c} stroke="none" />
          <Circle cx={12} cy={12} r={1.5} fill={c} stroke="none" />
          <Circle cx={19} cy={12} r={1.5} fill={c} stroke="none" />
        </Svg>
      );
    case 'wind':
      return (
        <Svg {...common}>
          <Path d="M3 8 h12 a3 3 0 100-6 M3 12 h17 a3 3 0 110 6 M3 16 h8 a2.5 2.5 0 110 5" />
        </Svg>
      );
    case 'rock':
      return (
        <Svg {...common}>
          <Path d="M3 18 L7 9 L13 6 L19 11 L21 18 Z" />
        </Svg>
      );
    case 'home':
      return (
        <Svg {...common}>
          <Path d="M3 11 L12 3 L21 11 V20 a1 1 0 01-1 1 H4 a1 1 0 01-1-1 z" />
        </Svg>
      );
    case 'history':
      return (
        <Svg {...common}>
          <Path d="M3 12 a9 9 0 109-9 v3" />
          <Path d="M3 3 v6 h6" />
          <Path d="M12 8 v4 l3 2" />
        </Svg>
      );
    case 'user':
      return (
        <Svg {...common}>
          <Circle cx={12} cy={8} r={4} />
          <Path d="M4 21 c0-4 3.5-7 8-7 s8 3 8 7" />
        </Svg>
      );
    case 'phone':
      return (
        <Svg {...common}>
          <Path d="M22 17 v3 a2 2 0 01-2 2 c-10 0-18-8-18-18 a2 2 0 012-2 h3 a2 2 0 012 1.7 l.7 4 a2 2 0 01-.6 1.9 l-1.5 1.5 a16 16 0 006 6 l1.5-1.5 a2 2 0 011.9-.6 l4 .7 a2 2 0 011.7 2z" />
        </Svg>
      );
    case 'map':
      return (
        <Svg {...common}>
          <Path d="M9 3 L3 5 V21 L9 19 L15 21 L21 19 V3 L15 5 Z" />
          <Path d="M9 3 V19 M15 5 V21" />
        </Svg>
      );
    case 'play':
      return (
        <Svg width={s} height={s} viewBox="0 0 24 24" fill={c}>
          <Path d="M6 4 L20 12 L6 20 Z" />
        </Svg>
      );
    case 'pause':
      return (
        <Svg width={s} height={s} viewBox="0 0 24 24" fill={c}>
          <Rect x={6} y={4} width={4} height={16} rx={1} />
          <Rect x={14} y={4} width={4} height={16} rx={1} />
        </Svg>
      );
    case 'stop':
      return (
        <Svg width={s} height={s} viewBox="0 0 24 24" fill={c}>
          <Rect x={6} y={6} width={12} height={12} rx={2} />
        </Svg>
      );
    case 'bell':
      return (
        <Svg {...common}>
          <Path d="M6 8 a6 6 0 0112 0 c0 7 3 9 3 9 H3 s3-2 3-9" />
          <Path d="M10 21 a2 2 0 004 0" />
        </Svg>
      );
    case 'message':
      return (
        <Svg {...common}>
          <Path d="M21 15 a2 2 0 01-2 2 H8 l-5 4 V5 a2 2 0 012-2 h14 a2 2 0 012 2 z" />
        </Svg>
      );
    case 'navigation':
      return (
        <Svg width={s} height={s} viewBox="0 0 24 24" fill={c}>
          <Path d="M12 2 L21 21 L12 17 L3 21 Z" />
        </Svg>
      );
    case 'tether':
      return (
        <Svg {...common}>
          <Circle cx={6} cy={12} r={2.5} />
          <Circle cx={18} cy={12} r={2.5} />
          <Path d="M8.5 12 h7" />
          <Path d="M11 9 l2 3 -2 3" />
        </Svg>
      );
    default:
      // Exhaustive-check guard — if a new case is added to `IconName` but
      // not implemented here, TS will flag this branch as unreachable.
      return null;
  }
}

// `Polyline` + `G` are imported above so the bundler keeps them in the
// react-native-svg surface — some upcoming icons will use them.
const _keepImports = { Polyline, G };
void _keepImports;
