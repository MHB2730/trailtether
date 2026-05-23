// Trailtether — segmented control.
//
// Hairline-bordered container with a sliding ember-tinted indicator that
// animates between tabs. Used in Community (Feed/Chat), Stats (My Hikes/
// Overall), Achievements (All/Unlocked/Locked), Sign In (Sign In/Create).
//
// Indicator transition: 350ms cubic-bezier(0.2, 0.7, 0.2, 1) per the
// handoff. Implemented with Reanimated so the slide is on the UI thread.

import React, { useEffect, useState } from 'react';
import {
  LayoutChangeEvent,
  Pressable,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import Animated, {
  Easing,
  useAnimatedStyle,
  useSharedValue,
  withTiming,
} from 'react-native-reanimated';
import { font, fz, ls, motion, radius, tt } from '@theme/tokens';

export interface SegmentedProps {
  options: readonly string[];
  active: number;
  onChange: (index: number) => void;
}

export function Segmented({ options, active, onChange }: SegmentedProps) {
  const [width, setWidth] = useState(0);
  const indicatorX = useSharedValue(0);

  // Recompute the indicator's x whenever the container width or active
  // index changes. Width is captured via onLayout once the container
  // settles.
  useEffect(() => {
    if (width === 0) return;
    const segWidth = width / options.length;
    indicatorX.value = withTiming(active * segWidth, {
      duration: 350,
      easing: Easing.bezier(...motion.easeOut),
    });
  }, [active, width, options.length, indicatorX]);

  const indicatorStyle = useAnimatedStyle(() => ({
    transform: [{ translateX: indicatorX.value }],
  }));

  const segWidth = width / options.length;

  const onLayout = (e: LayoutChangeEvent) => {
    const w = e.nativeEvent.layout.width;
    setWidth(w);
    // Pin the indicator to the active slot on the first layout pass so it
    // doesn't visibly slide in from x=0.
    indicatorX.value = active * (w / options.length);
  };

  return (
    <View style={styles.container} onLayout={onLayout}>
      {width > 0 && (
        <Animated.View
          style={[
            styles.indicator,
            { width: segWidth - 4 },
            indicatorStyle,
          ]}
        />
      )}
      {options.map((opt, i) => {
        const isActive = i === active;
        return (
          <Pressable
            key={opt}
            style={styles.option}
            onPress={() => onChange(i)}
            hitSlop={4}
          >
            <Text
              style={[
                styles.label,
                isActive ? styles.labelActive : styles.labelInactive,
              ]}
            >
              {opt}
            </Text>
          </Pressable>
        );
      })}
    </View>
  );
}

const styles = StyleSheet.create({
  container: {
    flexDirection: 'row',
    backgroundColor: tt.surf,
    borderRadius: radius.md,
    borderWidth: 1,
    borderColor: tt.line2,
    padding: 2,
    height: 36,
    position: 'relative',
    overflow: 'hidden',
  },
  indicator: {
    position: 'absolute',
    top: 2,
    bottom: 2,
    left: 2,
    backgroundColor: tt.emberDim,
    borderRadius: radius.md - 2,
    borderWidth: 1,
    borderColor: 'rgba(255,106,44,0.45)',
  },
  option: {
    flex: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  label: {
    fontFamily: font.uiBold,
    fontSize: fz.caption,
    letterSpacing: 0.04 * fz.caption,
  },
  labelActive: { color: tt.ember },
  labelInactive: { color: tt.text3 },
});
