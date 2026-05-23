// Trailtether — top app bar.
//
// Two modes per the handoff README:
//
//   * Tab screens (`big` = false): logo + "TRAIL[TETHER]" wordmark + optional
//     mono sub-eyebrow + right-aligned action buttons. Most screens use this.
//   * Detail screens (`big` = true): big <h1> title + optional sub eyebrow.
//
// Right-aligned `icon-btn`s are 38×38, radius 12, hairline border — handled
// by <IconBtn> for consistency.

import React from 'react';
import {
  Image,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { Icon, IconName } from '@components/Icon';
import { font, fz, ls, radius, sp, tt } from '@theme/tokens';

export interface AppBarProps {
  /** Title text shown when `big` is true. */
  title?: string;
  /** Mono uppercase eyebrow below the wordmark/title. */
  sub?: string;
  /** When true, renders a large `<h1>` title instead of the brand wordmark. */
  big?: boolean;
  /** Optional left-side back / menu icon (typically `chevron-up` for detail). */
  leftIcon?: IconName;
  onPressLeft?: () => void;
  /** Right-aligned action buttons. Pass a row of <IconBtn> elements. */
  right?: React.ReactNode;
}

export function TTAppBar({
  title,
  sub,
  big = false,
  leftIcon,
  onPressLeft,
  right,
}: AppBarProps) {
  return (
    <View style={styles.bar}>
      {leftIcon && (
        <IconBtn name={leftIcon} onPress={onPressLeft} />
      )}
      <View style={styles.center}>
        {big ? (
          <>
            {title && <Text style={styles.title}>{title}</Text>}
            {sub && <Text style={styles.sub}>{sub}</Text>}
          </>
        ) : (
          <>
            <View style={styles.brandRow}>
              {/* Drop-shadow ember halo behind the logo per the handoff. */}
              <Image
                source={require('../../../assets/logo.png')}
                style={styles.logo}
                resizeMode="contain"
              />
              <Text style={styles.wordmark}>
                TRAIL<Text style={styles.wordmarkAccent}>TETHER</Text>
              </Text>
            </View>
            {sub && <Text style={[styles.sub, styles.subInline]}>{sub}</Text>}
          </>
        )}
      </View>
      {right}
    </View>
  );
}

export interface IconBtnProps {
  name: IconName;
  onPress?: () => void;
  size?: number;
  color?: string;
}

export function IconBtn({
  name,
  onPress,
  size = 18,
  color = tt.text,
}: IconBtnProps) {
  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [
        styles.iconBtn,
        pressed && styles.iconBtnPressed,
      ]}
      hitSlop={6}
    >
      <Icon name={name} size={size} color={color} />
    </Pressable>
  );
}

const styles = StyleSheet.create({
  bar: {
    paddingTop: sp.s5,
    paddingBottom: sp.s6,
    paddingHorizontal: sp.screen,
    flexDirection: 'row',
    alignItems: 'center',
    gap: sp.s4,
  },
  center: { flex: 1, minWidth: 0 },
  brandRow: { flexDirection: 'row', alignItems: 'center', gap: 9 },
  logo: {
    width: 18,
    height: 18,
    // RN doesn't support CSS drop-shadow — the logo asset itself ships
    // with a subtle baked-in glow per the handoff asset notes.
  },
  wordmark: {
    fontFamily: font.uiHeavy,
    fontSize: 13,
    letterSpacing: ls.monoWide * 13,
    color: tt.text,
  },
  wordmarkAccent: { color: tt.ember },
  title: {
    fontFamily: font.uiHeavy,
    fontSize: fz.screenTitle,
    color: tt.text,
    letterSpacing: ls.tight * fz.screenTitle,
  },
  sub: {
    fontFamily: font.monoSemi,
    fontSize: 10.5,
    color: tt.text3,
    letterSpacing: ls.monoMed * 10.5,
    textTransform: 'uppercase',
  },
  subInline: { marginTop: 3 },
  iconBtn: {
    width: 38,
    height: 38,
    borderRadius: radius.md,
    backgroundColor: 'rgba(255,255,255,0.03)',
    borderWidth: 1,
    borderColor: tt.line,
    alignItems: 'center',
    justifyContent: 'center',
  },
  iconBtnPressed: { opacity: 0.7, transform: [{ scale: 0.97 }] },
});
