// Trailtether — surface card primitive.
//
// Wraps the standard .card pattern from the handoff: tt.surf background,
// 1px hairline border, radius 16, internal padding 14×16, dual shadow.
// Pass `tight` for the dense list-row variant (less padding, no shadow),
// `glass` for the floating-on-map variant (semi-transparent + blurry — RN
// uses a colour-only approximation here since BlurView requires expo-blur
// and we want this primitive to stay zero-dependency-extra).
//
// `onPress` makes it pressable with a subtle press-down scale, matching
// the .pressable affordance the handoff calls out.

import React from 'react';
import {
  Pressable,
  StyleSheet,
  View,
  ViewProps,
  ViewStyle,
} from 'react-native';
import { radius, shadow, sp, tt } from '@theme/tokens';

export interface CardProps extends ViewProps {
  tight?: boolean;
  glass?: boolean;
  onPress?: () => void;
  /**
   * Either a single padding value (applied to all sides) or a ViewStyle
   * fragment with the explicit padding* keys you want set. Defaults to
   * 14×16 (or 12 when `tight`).
   */
  padding?: number | Pick<ViewStyle,
    | 'padding'
    | 'paddingTop'
    | 'paddingBottom'
    | 'paddingLeft'
    | 'paddingRight'
    | 'paddingHorizontal'
    | 'paddingVertical'
    | 'paddingStart'
    | 'paddingEnd'>;
  contentStyle?: ViewStyle;
  children?: React.ReactNode;
}

export function Card({
  tight = false,
  glass = false,
  onPress,
  padding,
  style,
  contentStyle,
  children,
  ...rest
}: CardProps) {
  const pad =
    padding ?? (tight ? sp.s5 : { paddingVertical: sp.s6, paddingHorizontal: sp.s7 });
  const baseStyle: ViewStyle[] = [
    styles.base,
    glass ? styles.glass : styles.solid,
    typeof pad === 'number' ? { padding: pad } : (pad as ViewStyle),
    !tight && !glass ? shadow.card : {},
  ];

  if (onPress) {
    return (
      <Pressable
        onPress={onPress}
        style={({ pressed }) => [
          ...baseStyle,
          style as ViewStyle,
          pressed && styles.pressed,
        ]}
        {...rest}
      >
        <View style={contentStyle}>{children}</View>
      </Pressable>
    );
  }
  return (
    <View style={[...baseStyle, style] as ViewStyle[]} {...rest}>
      <View style={contentStyle}>{children}</View>
    </View>
  );
}

const styles = StyleSheet.create({
  base: {
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: tt.line,
  },
  solid: { backgroundColor: tt.surf },
  glass: {
    // Approximation of `rgba(13,17,22,0.72) + backdrop-blur` — without an
    // expo-blur backdrop we lean on a slightly heavier alpha to stand out
    // over the underlying map tiles.
    backgroundColor: 'rgba(13,17,22,0.78)',
    borderColor: tt.line2,
  },
  pressed: { opacity: 0.92, transform: [{ scale: 0.985 }] },
});
