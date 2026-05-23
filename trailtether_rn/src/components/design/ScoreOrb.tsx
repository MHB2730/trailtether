// Trailtether — ScoreOrb.
//
// Circular gauge that scores a forecast day 0–10 against the user's
// hiking thresholds. Color shifts with the score:
//   ≥7 → green, 5–6 → amber, <5 → red. Mirrors the forecast.jsx
// "ScoreOrb" component pixel-for-pixel (62×62 ring, 26 r, 4px stroke).
//
// The score number itself is sourced from `computeHikeScore()` in
// `src/data/adapters.ts` — never invent one inside this component.

import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import Svg, { Circle } from 'react-native-svg';
import { font, fz, ls, tt } from '@theme/tokens';

export interface ScoreOrbProps {
  /** 0–10 (clamped) */
  score: number;
}

export function ScoreOrb({ score }: ScoreOrbProps) {
  const clamped = Math.max(0, Math.min(10, score));
  const color = clamped >= 7 ? tt.green : clamped >= 5 ? tt.amber : tt.red;
  const dash = (clamped / 10) * 163;
  return (
    <View style={styles.wrap}>
      <Svg width={62} height={62} viewBox="0 0 62 62">
        <Circle cx={31} cy={31} r={26} fill="none" stroke="rgba(255,255,255,0.06)" strokeWidth={4} />
        <Circle
          cx={31}
          cy={31}
          r={26}
          fill="none"
          stroke={color}
          strokeWidth={4}
          strokeLinecap="round"
          strokeDasharray={`${dash} 1000`}
          transform="rotate(-90 31 31)"
        />
      </Svg>
      <View style={styles.inner} pointerEvents="none">
        <Text style={[styles.score, { color }]}>{clamped}</Text>
        <Text style={styles.label}>HIKE</Text>
      </View>
    </View>
  );
}

const styles = StyleSheet.create({
  wrap: {
    width: 62,
    height: 62,
    position: 'relative',
  },
  inner: {
    ...StyleSheet.absoluteFillObject,
    alignItems: 'center',
    justifyContent: 'center',
  },
  score: {
    fontFamily: font.monoBold,
    fontSize: 20,
    letterSpacing: ls.tight * 20,
  },
  label: {
    marginTop: 1,
    fontFamily: font.uiBold,
    fontSize: 7.5,
    color: tt.text3,
    letterSpacing: ls.monoWide * 7.5,
  },
});
