// Trailtether — ambient ember backdrop.
//
// Two soft radial-gradient ember bloom layers (top-right + bottom-left) that
// drift slowly on a 14s alternating loop. Matches the `.phone .screen::before`
// background in the design handoff: `radial-gradient(800x600 at 90% -10%,
// rgba(255,106,44,0.10), transparent 50%)` + a smaller mirror at the
// opposite corner.
//
// Built with react-native-svg radial gradients and animated via Reanimated
// so the breathing motion runs on the UI thread without dropping frames.

import React, { useEffect } from 'react';
import { StyleSheet, View } from 'react-native';
import Animated, {
  Easing,
  useAnimatedStyle,
  useSharedValue,
  withRepeat,
  withTiming,
} from 'react-native-reanimated';
import Svg, { Defs, RadialGradient, Rect, Stop } from 'react-native-svg';
import { motion } from '@theme/tokens';

export function AmbientBg() {
  // Single shared value drives both translateY and scale so the bloom
  // breathes in unison.
  const t = useSharedValue(0);
  useEffect(() => {
    t.value = withRepeat(
      withTiming(1, {
        duration: motion.ambient,
        easing: Easing.bezier(0.42, 0, 0.58, 1),
      }),
      -1,
      true, // reverse → "alternate" behaviour
    );
  }, [t]);

  const animStyle = useAnimatedStyle(() => ({
    opacity: 0.85 + t.value * 0.15,
    transform: [
      { translateY: -12 * t.value },
      { scale: 1 + 0.08 * t.value },
    ],
  }));

  return (
    <View pointerEvents="none" style={StyleSheet.absoluteFillObject}>
      <Animated.View style={[StyleSheet.absoluteFillObject, animStyle]}>
        <Svg width="100%" height="100%" preserveAspectRatio="none">
          <Defs>
            <RadialGradient
              id="emberTop"
              cx="90%"
              cy="-10%"
              rx="80%"
              ry="60%"
              fx="90%"
              fy="-10%"
            >
              <Stop offset="0" stopColor="#ff6a2c" stopOpacity="0.10" />
              <Stop offset="1" stopColor="#ff6a2c" stopOpacity="0" />
            </RadialGradient>
            <RadialGradient
              id="emberBottom"
              cx="-20%"
              cy="110%"
              rx="70%"
              ry="50%"
              fx="-20%"
              fy="110%"
            >
              <Stop offset="0" stopColor="#ff6a2c" stopOpacity="0.06" />
              <Stop offset="1" stopColor="#ff6a2c" stopOpacity="0" />
            </RadialGradient>
          </Defs>
          <Rect x="0" y="0" width="100%" height="100%" fill="url(#emberTop)" />
          <Rect x="0" y="0" width="100%" height="100%" fill="url(#emberBottom)" />
        </Svg>
      </Animated.View>
    </View>
  );
}
