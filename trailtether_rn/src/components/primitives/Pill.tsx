// Trailtether — pills & badges.
//
// `.pill` from the handoff: 22 tall, mono 9.5px/700, ALL-CAPS with 0.12em
// letter-spacing. Variants:
//
//   * default — neutral surface ring on bg2
//   * ember   — ember-tinted, used for the brand affordance
//   * live    — pulsing green dot + green label (online / tethered states)
//   * danger  — red ring + red label (SOS active, severe alerts)
//
// `<DifficultyChip>` is a sibling primitive that uses the fixed difficulty
// colour scale from `tokens.ts` so trail rows / chart legends stay in sync.

import React from 'react';
import { StyleSheet, Text, View } from 'react-native';
import {
  Difficulty,
  difficultyColor,
  font,
  ls,
  radius,
  tt,
} from '@theme/tokens';

export type PillVariant = 'default' | 'ember' | 'live' | 'danger';

export interface PillProps {
  label: string;
  variant?: PillVariant;
}

export function Pill({ label, variant = 'default' }: PillProps) {
  const spec = VARIANTS[variant];
  return (
    <View
      style={[
        styles.base,
        {
          backgroundColor: spec.bg,
          borderColor: spec.border,
        },
      ]}
    >
      {variant === 'live' && <View style={styles.liveDot} />}
      <Text style={[styles.label, { color: spec.text }]}>{label}</Text>
    </View>
  );
}

interface VariantSpec {
  bg: string;
  border: string;
  text: string;
}

const VARIANTS: Record<PillVariant, VariantSpec> = {
  default: {
    bg: tt.bg2,
    border: tt.line2,
    text: tt.text2,
  },
  ember: {
    bg: tt.emberDim,
    border: 'rgba(255,106,44,0.45)',
    text: tt.ember,
  },
  live: {
    bg: 'rgba(76,195,138,0.12)',
    border: 'rgba(76,195,138,0.45)',
    text: tt.green,
  },
  danger: {
    bg: 'rgba(230,61,46,0.12)',
    border: 'rgba(230,61,46,0.45)',
    text: tt.red,
  },
};

export interface DifficultyChipProps {
  difficulty: Difficulty;
  /** Optional override label — defaults to the difficulty name. */
  label?: string;
  small?: boolean;
}

export function DifficultyChip({
  difficulty,
  label,
  small = false,
}: DifficultyChipProps) {
  const color = difficultyColor(difficulty);
  return (
    <View
      style={[
        styles.diffBase,
        small && styles.diffSmall,
        {
          backgroundColor: `${color}1F`, // ~12% alpha
          borderColor: `${color}66`,
        },
      ]}
    >
      <Text
        style={[
          styles.diffLabel,
          small && styles.diffLabelSmall,
          { color },
        ]}
      >
        {(label ?? difficulty).toUpperCase()}
      </Text>
    </View>
  );
}

const styles = StyleSheet.create({
  base: {
    height: 22,
    paddingHorizontal: 10,
    borderRadius: radius.pill,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
    flexDirection: 'row',
    gap: 6,
    alignSelf: 'flex-start',
  },
  liveDot: {
    width: 6,
    height: 6,
    borderRadius: 3,
    backgroundColor: tt.green,
  },
  label: {
    fontFamily: font.monoBold,
    fontSize: 9.5,
    letterSpacing: ls.monoMed * 9.5,
    textTransform: 'uppercase',
  },
  diffBase: {
    paddingVertical: 3,
    paddingHorizontal: 9,
    borderRadius: 6,
    borderWidth: 1,
    alignSelf: 'flex-start',
  },
  diffSmall: { paddingVertical: 2, paddingHorizontal: 7 },
  diffLabel: {
    fontFamily: font.monoBold,
    fontSize: 9.5,
    letterSpacing: ls.monoMed * 9.5,
  },
  diffLabelSmall: { fontSize: 8.5 },
});
