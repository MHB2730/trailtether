// Trailtether — topographic backdrop.
//
// Renders the faint contour pattern that sits behind most screens. The web
// prototype uses a CSS `.topo-overlay` built from inline SVG; we ship the
// same shape here as a stretched react-native-svg layer.
//
// Drop one of these inside a parent that knows it (typically just under
// the ambient ember backdrop, above the body bg colour) and set
// `pointerEvents: 'none'` so it never eats taps.

import React from 'react';
import { StyleSheet, View } from 'react-native';
import Svg, { Path, Defs, LinearGradient, Stop } from 'react-native-svg';

export interface TopoBackdropProps {
  opacity?: number;
}

export function TopoBackdrop({ opacity = 0.7 }: TopoBackdropProps) {
  return (
    <View pointerEvents="none" style={[StyleSheet.absoluteFillObject, { opacity }]}>
      <Svg
        width="100%"
        height="100%"
        viewBox="0 0 400 800"
        preserveAspectRatio="none"
      >
        <Defs>
          <LinearGradient id="topoFade" x1="0" y1="0" x2="0" y2="1">
            <Stop offset="0" stopColor="#ffffff" stopOpacity="0.05" />
            <Stop offset="1" stopColor="#ffffff" stopOpacity="0.0" />
          </LinearGradient>
        </Defs>
        {/* Stacked Q-curve contours — same shapes as the .topo-overlay
            background SVG in design_source/index.html. Hand-picked y
            positions so they read like a topo map without dominating. */}
        {[80, 140, 220, 320, 420, 520, 620, 720].map((y, i) => (
          <Path
            key={i}
            d={`M -40 ${y} Q 80 ${y - 24} 200 ${y + 8} T 440 ${y - 12}`}
            stroke="rgba(255,255,255,0.06)"
            strokeWidth={1}
            fill="none"
          />
        ))}
        {/* Wider arcs for variety — emulates the canyon-rim look the
            handoff calls "topographic motif everywhere". */}
        {[60, 200, 380, 560].map((y, i) => (
          <Path
            key={`w${i}`}
            d={`M -40 ${y} Q 200 ${y - 50} 440 ${y}`}
            stroke="rgba(255,255,255,0.04)"
            strokeWidth={1}
            fill="none"
          />
        ))}
      </Svg>
    </View>
  );
}
