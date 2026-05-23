// Trailtether — AchievementMedallion.
//
// The hexagonal topo-survey marker used on the Profile screen and the
// dedicated Achievements screen. Mirrors `TopoMedallion` in profile.jsx
// 1:1 for the static parts: hex border, clipped contour lines, mountain
// silhouette, switchback trail, summit pin. Animations from the web
// design (radar rings, magma flicker, drifting embers) are stubbed —
// react-native-svg doesn't support `<animate>` directly, and adding
// reanimated drivers per pip would explode the bundle. Static still
// reads as on-brand because the topo + ember palette do the heavy
// lifting.
//
// Sizes: pass `size={56}` for grid cells, `size={96}` (with `large`)
// for the LatestUnlock hero spot.

import React from 'react';
import { StyleSheet, View } from 'react-native';
import Svg, {
  Circle,
  ClipPath,
  Defs,
  G,
  LinearGradient,
  Path,
  RadialGradient,
  Rect,
  Stop,
} from 'react-native-svg';
import { Icon, type IconName } from '@components/Icon';
import { rarityColor, type Rarity, tt } from '@theme/tokens';

export interface AchievementMedallionProps {
  /** Stable id — used to namespace svg defs (gradients, clips). */
  id: string;
  icon: IconName;
  rarity: Rarity;
  unlocked: boolean;
  /** 0–1 ember magma fill for locked-with-progress badges. Ignored when unlocked. */
  progress?: number;
  /** Default 56. */
  size?: number;
  /** Hero-mode rendering: thicker border + bigger center icon. */
  large?: boolean;
}

const TRAIL_D =
  'M 18,82 C 28,76 34,68 38,64 S 50,58 46,50 S 54,42 60,40 S 70,36 70,32';
const SUMMIT = { x: 70, y: 32 };
const HEX_D = 'M 50,4 L 92,27 L 92,73 L 50,96 L 8,73 L 8,27 Z';

export function AchievementMedallion({
  id,
  icon,
  rarity,
  unlocked,
  progress = 0,
  size = 56,
  large = false,
}: AchievementMedallionProps) {
  const r = rarityColor(rarity);
  const uid = `tm-${id}`;
  const centerIconSize = large ? 13 : 9;
  const centerWell = large ? 22 : 14;

  return (
    <View style={{ width: size, height: size, position: 'relative' }}>
      <Svg viewBox="0 0 100 100" width={size} height={size}>
        <Defs>
          <ClipPath id={`${uid}-clip`}>
            <Path d={HEX_D} />
          </ClipPath>
          <LinearGradient id={`${uid}-bg`} x1="0" y1="0" x2="0" y2="1">
            <Stop offset="0%" stopColor={unlocked ? '#1a1010' : '#11161c'} />
            <Stop offset="100%" stopColor="#06080b" />
          </LinearGradient>
          <LinearGradient id={`${uid}-magma`} x1="0" y1="1" x2="0" y2="0">
            <Stop offset="0%" stopColor={r.ring} stopOpacity="0.85" />
            <Stop offset="100%" stopColor={r.ring} stopOpacity="0" />
          </LinearGradient>
          <LinearGradient id={`${uid}-trail`} x1="0" y1="0" x2="1" y2="0">
            <Stop offset="0%" stopColor={r.ring} stopOpacity="0" />
            <Stop offset="30%" stopColor={r.fill} stopOpacity="1" />
            <Stop offset="100%" stopColor="#fff4d6" stopOpacity="1" />
          </LinearGradient>
          <RadialGradient id={`${uid}-pin`} cx="50%" cy="50%" r="50%">
            <Stop offset="0%" stopColor="#fff4d6" />
            <Stop offset="50%" stopColor={r.fill} />
            <Stop offset="100%" stopColor={r.ring} stopOpacity="0" />
          </RadialGradient>
        </Defs>

        <G clipPath={`url(#${uid}-clip)`}>
          <Rect width={100} height={100} fill={`url(#${uid}-bg)`} />

          {/* Topo contour lines */}
          <G
            stroke={unlocked ? `${r.fill}33` : 'rgba(255,255,255,0.06)'}
            fill="none"
            strokeWidth={0.5}
          >
            <Path d="M -10,40 Q 30,32 50,38 T 110,40" />
            <Path d="M -10,52 Q 30,44 50,50 T 110,52" />
            <Path d="M -10,64 Q 30,56 50,62 T 110,64" />
            <Path d="M -10,76 Q 30,68 50,74 T 110,76" />
            <Path d="M -10,88 Q 30,80 50,86 T 110,88" />
          </G>

          {/* Radar ring — static, since RN-SVG can't animate `r` natively */}
          {unlocked && (
            <Circle
              cx={SUMMIT.x}
              cy={SUMMIT.y}
              r={20}
              fill="none"
              stroke={r.fill}
              strokeWidth={0.6}
              opacity={0.35}
            />
          )}

          {/* Ember magma fill for locked-with-progress */}
          {!unlocked && progress > 0 && (
            <Rect
              x={0}
              y={100 - progress * 92}
              width={100}
              height={progress * 92 + 8}
              fill={`url(#${uid}-magma)`}
              opacity={0.7}
            />
          )}

          {/* Mountain silhouette */}
          <Path
            d="M 5 92 L 22 70 L 32 78 L 44 60 L 56 70 L 70 32 L 84 64 L 95 92 Z"
            fill={unlocked ? '#05060a' : '#0d1218'}
            stroke={unlocked ? `${r.fill}66` : 'rgba(255,255,255,0.10)'}
            strokeWidth={0.7}
            strokeLinejoin="round"
          />

          {/* Switchback trail — drawn solid (no dashed animation) when unlocked */}
          {unlocked && (
            <>
              <Path
                d={TRAIL_D}
                fill="none"
                stroke={r.fill}
                strokeWidth={3.2}
                strokeLinecap="round"
                opacity={0.5}
              />
              <Path
                d={TRAIL_D}
                fill="none"
                stroke={`url(#${uid}-trail)`}
                strokeWidth={1.4}
                strokeLinecap="round"
              />
            </>
          )}

          {/* Summit pin */}
          {unlocked ? (
            <>
              <Circle cx={SUMMIT.x} cy={SUMMIT.y} r={5} fill={`url(#${uid}-pin)`} />
              <Circle cx={SUMMIT.x} cy={SUMMIT.y} r={1.8} fill="#fff4d6" />
            </>
          ) : (
            <Circle cx={SUMMIT.x} cy={SUMMIT.y} r={1.2} fill="rgba(255,255,255,0.18)" />
          )}

          {/* Reticle corner brackets — survey-marker vibe */}
          <G
            stroke={unlocked ? r.fill : 'rgba(255,255,255,0.18)'}
            strokeWidth={1}
            fill="none"
            strokeLinecap="round"
            opacity={unlocked ? 0.85 : 0.45}
          >
            <Path d="M 10 28 L 16 25" />
            <Path d="M 90 28 L 84 25" />
            <Path d="M 10 72 L 16 75" />
            <Path d="M 90 72 L 84 75" />
          </G>
        </G>

        {/* Hex border — last so it sits above content */}
        <Path
          d={HEX_D}
          fill="none"
          stroke={unlocked ? r.ring : tt.line3}
          strokeWidth={large ? 1.6 : 1.4}
          opacity={unlocked ? 1 : 0.7}
        />
      </Svg>

      {/* Center icon over the medallion */}
      <View
        style={[
          styles.centerIcon,
          {
            width: centerWell,
            height: centerWell,
            top: '50%',
            left: '50%',
            marginLeft: -centerWell / 2,
            marginTop: -centerWell / 2 - (size * 0.04),
            backgroundColor: unlocked ? '#0a0c0f' : 'transparent',
            borderWidth: unlocked ? 1.5 : 0,
            borderColor: r.ring,
          },
        ]}
      >
        <Icon
          name={icon}
          size={centerIconSize}
          color={unlocked ? r.fill : tt.text3}
          strokeWidth={2.2}
        />
      </View>

      {/* Lock chip for locked badges */}
      {!unlocked && (
        <View style={styles.lockChip}>
          <Svg width={9} height={10} viewBox="0 0 9 10">
            <Rect x={1.6} y={4.4} width={5.8} height={4.6} rx={0.9} fill="#98a1ac" />
            <Path
              d="M2.6 4.4 v-1.6 a1.9 1.9 0 013.8 0 V4.4"
              stroke="#98a1ac"
              strokeWidth={1}
              fill="none"
            />
          </Svg>
        </View>
      )}
    </View>
  );
}

const styles = StyleSheet.create({
  centerIcon: {
    position: 'absolute',
    borderRadius: 999,
    alignItems: 'center',
    justifyContent: 'center',
  },
  lockChip: {
    position: 'absolute',
    bottom: -2,
    right: -2,
    width: 18,
    height: 18,
    borderRadius: 9,
    backgroundColor: tt.bg3,
    borderWidth: 1.5,
    borderColor: tt.line3,
    alignItems: 'center',
    justifyContent: 'center',
  },
});
