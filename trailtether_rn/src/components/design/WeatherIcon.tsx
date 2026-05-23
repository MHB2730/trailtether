// Trailtether — WeatherIcon.
//
// SVG weather glyphs. Three sizes:
//   - WeatherIcon size="sm"  → row use (forecast strip, hourly chart axis)
//   - WeatherIcon size="md"  → home weather card next to temperature
//   - WeatherIcon size="lg"  → hero spot on the forecast screen
//
// Kind is normalized upstream by `weatherIconKind(weather_code)`. The
// `cloud` and `rain` glyphs share an ellipse stack; `sun` is a radial
// ember disc with eight rays. `moon` exists only in `sm` (forecast night
// rows in the wall-of-tiles).

import React from 'react';
import Svg, { Circle, Ellipse, Line, Path, RadialGradient, Defs, Stop } from 'react-native-svg';
import type { WeatherIconKind } from '@/data/enums';
import { tt } from '@theme/tokens';

export type WeatherIconSize = 'sm' | 'md' | 'lg';

export interface WeatherIconProps {
  kind: WeatherIconKind | 'moon';
  size?: WeatherIconSize;
}

export function WeatherIcon({ kind, size = 'md' }: WeatherIconProps) {
  if (size === 'sm') return <WxSmall kind={kind} />;
  if (size === 'lg') return <WxLarge kind={kind} />;
  return <WxMid kind={kind} />;
}

function WxSmall({ kind }: { kind: WeatherIconKind | 'moon' }) {
  if (kind === 'sun') {
    return (
      <Svg width={14} height={14} viewBox="0 0 14 14">
        <Circle cx={7} cy={7} r={3} fill={tt.ember2} />
        {sunRays(7, 7, 4, 6, 1.2, tt.ember2)}
      </Svg>
    );
  }
  if (kind === 'cloud') {
    return (
      <Svg width={16} height={12} viewBox="0 0 16 12">
        <Ellipse cx={5} cy={8} rx={4} ry={2.5} fill="#5a6470" />
        <Ellipse cx={10} cy={8} rx={3.5} ry={2} fill="#5a6470" />
        <Ellipse cx={8} cy={6} rx={3} ry={2} fill="#7a8390" />
      </Svg>
    );
  }
  if (kind === 'moon') {
    return (
      <Svg width={14} height={14} viewBox="0 0 14 14">
        <Path d="M11 8.5 a4.5 4.5 0 11-5.5-5.5 a3.5 3.5 0 105.5 5.5z" fill="#98a1ac" />
      </Svg>
    );
  }
  // rain
  return (
    <Svg width={14} height={14} viewBox="0 0 14 14">
      <Ellipse cx={4} cy={5} rx={3.5} ry={2} fill="#5a6470" />
      <Ellipse cx={9} cy={6} rx={3} ry={1.8} fill="#5a6470" />
      <Line x1={3} y1={9} x2={2} y2={13} stroke={tt.blue} strokeWidth={1.2} />
      <Line x1={6} y1={9} x2={5} y2={13} stroke={tt.blue} strokeWidth={1.2} />
      <Line x1={9} y1={9} x2={8} y2={13} stroke={tt.blue} strokeWidth={1.2} />
    </Svg>
  );
}

function WxMid({ kind }: { kind: WeatherIconKind | 'moon' }) {
  if (kind === 'sun') {
    return (
      <Svg width={16} height={16} viewBox="0 0 16 16">
        <Circle cx={8} cy={8} r={3} fill={tt.ember2} />
        {sunRays(8, 8, 5, 7, 1.4, tt.ember2)}
      </Svg>
    );
  }
  if (kind === 'cloud') {
    return (
      <Svg width={18} height={14} viewBox="0 0 18 14">
        <Ellipse cx={6} cy={10} rx={5} ry={3} fill="#5a6470" />
        <Ellipse cx={12} cy={10} rx={4} ry={2.5} fill="#5a6470" />
        <Ellipse cx={9} cy={7} rx={3.5} ry={2.5} fill="#5a6470" />
      </Svg>
    );
  }
  if (kind === 'moon') {
    return (
      <Svg width={14} height={14} viewBox="0 0 14 14">
        <Path d="M11 8.5 a4.5 4.5 0 11-5.5-5.5 a3.5 3.5 0 105.5 5.5z" fill="#98a1ac" />
      </Svg>
    );
  }
  return (
    <Svg width={16} height={16} viewBox="0 0 16 16">
      <Ellipse cx={5} cy={6} rx={4} ry={2.4} fill="#5a6470" />
      <Ellipse cx={10} cy={7} rx={3.4} ry={2.1} fill="#5a6470" />
      <Line x1={4} y1={10} x2={3} y2={14} stroke={tt.blue} strokeWidth={1.3} />
      <Line x1={7} y1={10} x2={6} y2={14} stroke={tt.blue} strokeWidth={1.3} />
      <Line x1={10} y1={10} x2={9} y2={14} stroke={tt.blue} strokeWidth={1.3} />
    </Svg>
  );
}

function WxLarge({ kind }: { kind: WeatherIconKind | 'moon' }) {
  if (kind === 'sun') {
    return (
      <Svg width={74} height={74} viewBox="0 0 74 74">
        <Defs>
          <RadialGradient id="bigSunG" cx="50%" cy="50%" r="50%">
            <Stop offset="0%" stopColor="#ffe2c2" />
            <Stop offset="100%" stopColor={tt.ember} />
          </RadialGradient>
        </Defs>
        <Circle cx={37} cy={37} r={20} fill="url(#bigSunG)" />
        {sunRaysAbs(37, 37, 26, 32, 2, tt.ember2)}
      </Svg>
    );
  }
  if (kind === 'cloud') {
    return (
      <Svg width={74} height={64} viewBox="0 0 74 64">
        <Ellipse cx={22} cy={42} rx={20} ry={13} fill="#3a4150" />
        <Ellipse cx={48} cy={44} rx={16} ry={10} fill="#3a4150" />
        <Ellipse cx={36} cy={32} rx={14} ry={9} fill="#5a6470" />
      </Svg>
    );
  }
  // rain
  return (
    <Svg width={74} height={74} viewBox="0 0 74 74">
      <Ellipse cx={22} cy={34} rx={20} ry={12} fill="#3a4150" />
      <Ellipse cx={48} cy={36} rx={16} ry={9} fill="#3a4150" />
      {[12, 24, 36, 48, 60].map((x) => (
        <Line
          key={x}
          x1={x}
          y1={48}
          x2={x - 2}
          y2={66}
          stroke={tt.blue}
          strokeWidth={1.8}
          strokeLinecap="round"
          opacity={0.7}
        />
      ))}
    </Svg>
  );
}

function sunRays(
  cx: number,
  cy: number,
  inner: number,
  outer: number,
  width: number,
  color: string,
) {
  return Array.from({ length: 8 }).map((_, i) => {
    const a = (i * Math.PI) / 4;
    return (
      <Line
        key={i}
        x1={cx + Math.cos(a) * inner}
        y1={cy + Math.sin(a) * inner}
        x2={cx + Math.cos(a) * outer}
        y2={cy + Math.sin(a) * outer}
        stroke={color}
        strokeWidth={width}
        strokeLinecap="round"
      />
    );
  });
}

function sunRaysAbs(
  cx: number,
  cy: number,
  inner: number,
  outer: number,
  width: number,
  color: string,
) {
  return Array.from({ length: 8 }).map((_, i) => {
    const a = (i * Math.PI) / 4;
    return (
      <Line
        key={i}
        x1={cx + Math.cos(a) * inner}
        y1={cy + Math.sin(a) * inner}
        x2={cx + Math.cos(a) * outer}
        y2={cy + Math.sin(a) * outer}
        stroke={color}
        strokeWidth={width}
        strokeLinecap="round"
        opacity={0.7}
      />
    );
  });
}
