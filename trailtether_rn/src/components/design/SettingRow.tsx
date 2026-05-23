// Trailtether — SettingRow.
//
// The repeating row used inside Settings + the small settings list on
// the Profile screen. Slot composition:
//   [icon tile] [label + optional sub] [optional toggle | synced | value | badge] [chevron]
//
// Mirrors `SettingRowS` (settings.jsx) and the older `SettingRow`
// (profile.jsx) — the merged shape supports both call sites.

import React, { useState } from 'react';
import {
  Pressable,
  StyleSheet,
  Switch,
  Text,
  View,
  ViewStyle,
} from 'react-native';
import { Icon, type IconName } from '@components/Icon';
import { font, fz, ls, radius, sp, tt } from '@theme/tokens';

export interface SettingRowProps {
  icon: IconName;
  label: string;
  sub?: string;
  /** Show a toggle. Controlled via `toggleOn` + `onToggle`; uncontrolled if either missing. */
  toggle?: boolean;
  toggleOn?: boolean;
  onToggle?: (next: boolean) => void;
  /** Show a "SYNCED" green chip (Health Connect, etc.). */
  synced?: boolean;
  /** Right-aligned ember value text ("Manage", "On", etc.). */
  value?: string;
  /** Colored mono badge ("BETA", "NEW"). */
  badge?: { label: string; color: string };
  /** Hide chevron + bottom border for the last item in a group. */
  isLast?: boolean;
  onPress?: () => void;
  style?: ViewStyle;
}

export function SettingRow({
  icon,
  label,
  sub,
  toggle,
  toggleOn,
  onToggle,
  synced,
  value,
  badge,
  isLast,
  onPress,
  style,
}: SettingRowProps) {
  // Uncontrolled fallback for toggle rows that don't pass a state.
  const [local, setLocal] = useState(false);
  const isControlled = toggleOn !== undefined;
  const on = isControlled ? !!toggleOn : local;
  const handleToggle = (next: boolean) => {
    if (!isControlled) setLocal(next);
    onToggle?.(next);
  };

  const showChevron = !toggle && !synced && !badge && !value;

  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [
        styles.row,
        !isLast && styles.rowDivider,
        pressed && onPress && { backgroundColor: tt.surf2 },
        style,
      ]}
      disabled={!onPress}
    >
      <View style={styles.iconTile}>
        <Icon name={icon} size={14} color={tt.ember} />
      </View>
      <View style={{ flex: 1, minWidth: 0 }}>
        <Text style={styles.label} numberOfLines={1}>{label}</Text>
        {sub && <Text style={styles.sub} numberOfLines={1}>{sub}</Text>}
      </View>

      {toggle && (
        <Switch
          value={on}
          onValueChange={handleToggle}
          trackColor={{ false: tt.surf3, true: tt.ember }}
          thumbColor="#fff"
          ios_backgroundColor={tt.surf3}
        />
      )}

      {synced && (
        <View style={styles.syncedChip}>
          <Icon name="check" size={10} color={tt.green} strokeWidth={2.4} />
          <Text style={styles.syncedText}>SYNCED</Text>
        </View>
      )}

      {badge && (
        <View
          style={[
            styles.badge,
            { backgroundColor: `${badge.color}1f`, borderColor: `${badge.color}55` },
          ]}
        >
          <Text style={[styles.badgeText, { color: badge.color }]}>{badge.label}</Text>
        </View>
      )}

      {value && !toggle && !synced && (
        <Text style={styles.value}>{value}</Text>
      )}

      {showChevron && <Icon name="chevron-right" size={14} color={tt.text3} />}
    </Pressable>
  );
}

const styles = StyleSheet.create({
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: sp.s5,
    paddingVertical: sp.s5,
    paddingHorizontal: sp.s6,
  },
  rowDivider: {
    borderBottomWidth: 1,
    borderBottomColor: tt.line,
  },
  iconTile: {
    width: 34,
    height: 34,
    borderRadius: 9,
    backgroundColor: 'rgba(255,255,255,0.03)',
    borderWidth: 1,
    borderColor: tt.line2,
    alignItems: 'center',
    justifyContent: 'center',
  },
  label: {
    fontFamily: font.uiBold,
    fontSize: 13,
    color: tt.text,
  },
  sub: {
    marginTop: 2,
    fontFamily: font.monoSemi,
    fontSize: fz.micro2,
    color: tt.text3,
    letterSpacing: ls.monoTight * fz.micro2,
  },
  value: {
    fontFamily: font.monoBold,
    fontSize: fz.caption,
    color: tt.ember,
    letterSpacing: ls.monoTight * fz.caption,
  },
  syncedChip: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
    paddingVertical: 4,
    paddingHorizontal: sp.s3,
    borderRadius: 6,
    backgroundColor: 'rgba(76,195,138,0.13)',
    borderWidth: 1,
    borderColor: 'rgba(76,195,138,0.3)',
  },
  syncedText: {
    fontFamily: font.monoBold,
    fontSize: 9,
    color: tt.green,
    letterSpacing: ls.monoMed * 9,
  },
  badge: {
    paddingVertical: 2,
    paddingHorizontal: 7,
    borderRadius: 5,
    borderWidth: 1,
  },
  badgeText: {
    fontFamily: font.monoBold,
    fontSize: 8.5,
    letterSpacing: ls.monoWide * 8.5,
  },
});

// Group container used to stack rows in a single card. Mirrors the
// `SettingsGroup` pattern in settings.jsx.
export interface SettingsGroupProps {
  title?: string;
  children: React.ReactNode;
  style?: ViewStyle;
}

export function SettingsGroup({ title, children, style }: SettingsGroupProps) {
  return (
    <View style={[{ marginTop: sp.s7 }, style]}>
      {title && <Text style={groupStyles.title}>{title}</Text>}
      <View style={groupStyles.card}>{children}</View>
    </View>
  );
}

const groupStyles = StyleSheet.create({
  title: {
    fontFamily: font.uiBold,
    fontSize: fz.micro2,
    color: tt.text2,
    letterSpacing: ls.monoWide * fz.micro2,
    textTransform: 'uppercase',
    marginBottom: sp.s4,
    paddingHorizontal: sp.s2,
  },
  card: {
    backgroundColor: tt.surf,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: tt.line,
    overflow: 'hidden',
  },
});
