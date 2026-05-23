// Trailtether — HazardGlyph.
//
// The colored chip that appears alongside trail hazards, nearby-hazard
// rows, and pips on the elevation chart. Mirrors `HAZARD_META` in
// trail-detail.jsx — the kind controls both color and the icon that
// rides inside it.
//
// Two presentation modes:
//   - chip  → rounded pill with colored fill + label (for rows)
//   - dot   → 14×14 colored circle (for map pips / elevation chart)

import React from 'react';
import { StyleSheet, Text, View, ViewStyle } from 'react-native';
import { Icon, type IconName } from '@components/Icon';
import type { TrailHazardKind } from '@/data/enums';
import { font, fz, ls, radius, tt } from '@theme/tokens';

interface HazardMeta {
  color: string;
  icon: IconName;
  glyph: string;
}

const HAZARD_META: Record<TrailHazardKind, HazardMeta> = {
  water: { color: tt.blue, icon: 'wind', glyph: '~' },
  shelter: { color: tt.green, icon: 'rock', glyph: '⌂' },
  danger: { color: tt.red, icon: 'alert', glyph: '!' },
  view: { color: tt.amber, icon: 'eye', glyph: '◉' },
  summit: { color: tt.ember, icon: 'mountain', glyph: '▲' },
};

export function hazardMeta(kind: TrailHazardKind): HazardMeta {
  return HAZARD_META[kind];
}

export interface HazardGlyphProps {
  kind: TrailHazardKind;
  label?: string;
  variant?: 'chip' | 'dot';
  style?: ViewStyle;
}

export function HazardGlyph({ kind, label, variant = 'chip', style }: HazardGlyphProps) {
  const m = HAZARD_META[kind];
  if (variant === 'dot') {
    return (
      <View
        style={[
          {
            width: 14,
            height: 14,
            borderRadius: 7,
            backgroundColor: `${m.color}33`,
            borderWidth: 1,
            borderColor: m.color,
            alignItems: 'center',
            justifyContent: 'center',
          },
          style,
        ]}
      >
        <Text style={{ fontFamily: font.monoBold, fontSize: 7, color: m.color }}>{m.glyph}</Text>
      </View>
    );
  }
  return (
    <View
      style={[
        styles.chip,
        {
          backgroundColor: `${m.color}1f`,
          borderColor: `${m.color}55`,
        },
        style,
      ]}
    >
      <Icon name={m.icon} size={11} color={m.color} />
      {label && (
        <Text style={[styles.label, { color: m.color }]}>{label.toUpperCase()}</Text>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  chip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingVertical: 3,
    paddingHorizontal: 7,
    borderRadius: radius.sm,
    borderWidth: 1,
  },
  label: {
    fontFamily: font.monoBold,
    fontSize: fz.micro,
    letterSpacing: ls.monoMed * fz.micro,
  },
});
