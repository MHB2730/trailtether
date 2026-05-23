// Trailtether — ChipRow.
//
// Horizontal row of single-select chips with an animated ember pill
// indicator. Used for filter rows like:
//   - Search → "ALL · TRAILS · CAVES · CAMPS"
//   - History → "ALL · MONTH · 90 DAYS"
//   - Forecast → location chips
//
// Differs from `Segmented`: ChipRow is for filters whose count is
// data-driven and may exceed the viewport — it scrolls horizontally
// instead of stretching to fill width.

import React from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View, ViewStyle } from 'react-native';
import { font, fz, ls, radius, sp, tt } from '@theme/tokens';

export interface ChipRowItem {
  /** Stable id — passed back to `onChange`. */
  id: string;
  label: string;
  /** Optional right-aligned counter (e.g., "239"). */
  count?: number;
}

export interface ChipRowProps {
  items: ChipRowItem[];
  value: string;
  onChange: (id: string) => void;
  style?: ViewStyle;
  /** Render full-width (no scroll) — use when items fit. */
  fitted?: boolean;
}

export function ChipRow({ items, value, onChange, style, fitted = false }: ChipRowProps) {
  const body = items.map((it) => {
    const active = it.id === value;
    return (
      <Pressable
        key={it.id}
        onPress={() => onChange(it.id)}
        style={({ pressed }) => [
          styles.chip,
          active && styles.chipActive,
          pressed && { opacity: 0.8 },
        ]}
      >
        <Text style={[styles.text, active && styles.textActive]} numberOfLines={1}>
          {it.label.toUpperCase()}
        </Text>
        {typeof it.count === 'number' && (
          <Text style={[styles.count, active && styles.countActive]}>{it.count}</Text>
        )}
      </Pressable>
    );
  });

  if (fitted) {
    return <View style={[styles.row, style]}>{body}</View>;
  }
  return (
    <ScrollView
      horizontal
      showsHorizontalScrollIndicator={false}
      contentContainerStyle={styles.row}
      style={style}
    >
      {body}
    </ScrollView>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    gap: sp.s3,
    paddingVertical: 2,
  },
  chip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 6,
    paddingVertical: 7,
    paddingHorizontal: sp.s5,
    borderRadius: radius.pill,
    backgroundColor: tt.surf,
    borderWidth: 1,
    borderColor: tt.line2,
  },
  chipActive: {
    backgroundColor: tt.emberDim,
    borderColor: 'rgba(255,106,44,0.45)',
  },
  text: {
    fontFamily: font.uiBold,
    fontSize: 10.5,
    color: tt.text2,
    letterSpacing: ls.monoMed * 10.5,
  },
  textActive: {
    color: tt.ember,
  },
  count: {
    fontFamily: font.monoBold,
    fontSize: 9.5,
    color: tt.text3,
    letterSpacing: ls.monoTight * 9.5,
  },
  countActive: {
    color: tt.ember2,
  },
});
