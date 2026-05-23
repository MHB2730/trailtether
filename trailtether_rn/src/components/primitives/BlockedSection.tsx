// Trailtether — BlockedSection.
//
// Renders inside any Card/section whose data shape doesn't have a
// backing endpoint yet. Mirrors `ErrorState` visually but with a
// distinct icon + an explicit pointer to the BLOCKERS.md entry so a
// reviewer immediately knows this isn't a runtime error — it's a
// tracked-and-documented gap.
//
// Per the implementation rules, blocked surfaces ship as
// `<BlockedSection number={X} />` instead of mock data or empty
// fallbacks.

import React from 'react';
import { Pressable, StyleSheet, Text, View, ViewStyle } from 'react-native';
import { Icon } from '@components/Icon';
import { font, fz, ls, radius, sp, tt } from '@theme/tokens';

export interface BlockedSectionProps {
  /** BLOCKERS.md entry number (e.g. 10 for `v_trail_metadata`). */
  number: number;
  /** Short label that fits inside a row. */
  title: string;
  /** Optional longer note. */
  note?: string;
  /** Render compact, for inline use inside a tightly-padded row. */
  inline?: boolean;
  style?: ViewStyle;
  /** Optional override — usually points the user at the docs page. */
  onPress?: () => void;
}

export function BlockedSection({
  number,
  title,
  note,
  inline = false,
  style,
  onPress,
}: BlockedSectionProps) {
  const body = (
    <View style={[inline ? styles.inline : styles.block, style]}>
      <View style={styles.iconWrap}>
        <Icon name="alert" size={14} color={tt.amber} />
      </View>
      <View style={{ flex: 1, minWidth: 0 }}>
        <Text style={styles.title}>{title}</Text>
        {note && <Text style={styles.note}>{note}</Text>}
        <Text style={styles.tag}>
          BLOCKERS.md · #{number.toString().padStart(2, '0')}
        </Text>
      </View>
    </View>
  );
  if (onPress) {
    return (
      <Pressable
        onPress={onPress}
        style={({ pressed }) => [pressed && { opacity: 0.6 }]}
      >
        {body}
      </Pressable>
    );
  }
  return body;
}

const styles = StyleSheet.create({
  block: {
    flexDirection: 'row',
    alignItems: 'flex-start',
    gap: sp.s4,
    padding: sp.s5,
    borderRadius: radius.md,
    backgroundColor: 'rgba(242,169,59,0.06)',
    borderWidth: 1,
    borderColor: 'rgba(242,169,59,0.32)',
  },
  inline: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: sp.s3,
    paddingVertical: sp.s4,
  },
  iconWrap: {
    width: 28,
    height: 28,
    borderRadius: 8,
    backgroundColor: 'rgba(242,169,59,0.14)',
    borderWidth: 1,
    borderColor: 'rgba(242,169,59,0.32)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  title: {
    fontFamily: font.uiBold,
    fontSize: fz.body2,
    color: tt.text,
  },
  note: {
    marginTop: 4,
    fontFamily: font.uiMed,
    fontSize: fz.body,
    color: tt.text3,
  },
  tag: {
    marginTop: 6,
    fontFamily: font.monoBold,
    fontSize: 9.5,
    color: tt.amber,
    letterSpacing: ls.monoMed * 9.5,
  },
});
