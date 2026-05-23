// Trailtether — Trail Detail.
//
// Pulls one trail from the bundled `useTrail()` hook by `?id=` param,
// plus editorial extras (segments / hazards / prep) from
// `useTrailExtras()` which reads the v_trail_metadata view (BLOCKERS
// #10 resolved). When the trail has no editorial entry yet the extras
// section renders an inline "No editorial data" note instead of a
// BlockedSection — the view exists, the row just doesn't.

import React from 'react';
import {
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { useLocalSearchParams, useRouter } from 'expo-router';
import Svg, { Defs, LinearGradient, Path, Stop } from 'react-native-svg';
import { ScreenShell } from '@components/primitives/ScreenShell';
import { TTAppBar, IconBtn } from '@components/primitives/TTAppBar';
import { Card } from '@components/primitives/Card';
import { DifficultyChip } from '@components/primitives/Pill';
import { HazardGlyph } from '@components/design/HazardGlyph';
import { TrailMap } from '@components/design/TrailMap';
import { BlockedSection } from '@components/primitives/BlockedSection';
import { ErrorState, LoadingState } from '@components/primitives/States';
import { Icon } from '@components/Icon';
import { useTrail, useTrailExtras, parseBlocked } from '@/data/hooks';
import { hoursMinutesLabel, thousandsLabel } from '@/data/adapters';
import { font, fz, ls, shadow, sp, tt } from '@theme/tokens';

export default function TrailDetailScreen() {
  const router = useRouter();
  const params = useLocalSearchParams<{ id?: string }>();
  const id = typeof params.id === 'string' ? params.id : null;
  const trail = useTrail(id);
  const extras = useTrailExtras(id);
  const blocked = parseBlocked(trail.error);

  return (
    <ScreenShell>
      <TTAppBar
        big
        title={trail.data?.name ?? 'Trail Detail'}
        sub={trail.data?.region.toUpperCase() ?? ''}
        leftIcon="chevron-up"
        onPressLeft={() => router.back()}
        right={<IconBtn name="send-fill" />}
      />
      <ScrollView
        contentContainerStyle={styles.body}
        showsVerticalScrollIndicator={false}
      >
        {!id && (
          <ErrorState error="No trail id supplied. Open from /trails." />
        )}
        {id && trail.loading && <LoadingState />}
        {id && blocked && (
          <BlockedSection
            number={blocked.n}
            title="Trail bundle pending"
            note={blocked.reason}
          />
        )}
        {id && !trail.loading && !blocked && trail.error && (
          <ErrorState error={trail.error} onRetry={trail.refetch} />
        )}

        {trail.data && (
          <>
            <Card>
              <View style={styles.headerRow}>
                <View style={{ flex: 1 }}>
                  <Text style={styles.region}>{trail.data.region.toUpperCase()}</Text>
                  <Text style={styles.title}>{trail.data.name}</Text>
                  <View style={{ marginTop: sp.s3 }}>
                    <DifficultyChip difficulty={trail.data.difficulty} />
                  </View>
                </View>
                <View style={styles.statsBlock}>
                  <Stat label="DIST" value={trail.data.distanceKm.toFixed(1)} unit="km" />
                  <Stat
                    label="ASCENT"
                    value={thousandsLabel(trail.data.ascentM)}
                    unit="m"
                    ember
                  />
                  <Stat
                    label="EST."
                    value={hoursMinutesLabel(trail.data.estTimeHours * 3600)}
                    unit="h"
                  />
                </View>
              </View>

              {trail.data.description.length > 0 && (
                <Text style={styles.description}>{trail.data.description}</Text>
              )}
            </Card>

            <Text style={styles.sectionTitle}>ROUTE</Text>
            <View style={styles.mapWrap}>
              <TrailMap trails={[trail.data]} fitToTrail />
            </View>

            <Text style={styles.sectionTitle}>ELEVATION PROFILE</Text>
            <Card>
              <ElevationChart elev={trail.data.elev} />
              <View style={styles.elevRow}>
                <Text style={styles.elevMeta}>
                  Base {trail.data.baseM} m · Top{' '}
                  {Math.round(trail.data.baseM + trail.data.ascentM)} m
                </Text>
                <Text style={styles.elevMeta}>
                  ↓ {thousandsLabel(trail.data.descentM)} m
                </Text>
              </View>
            </Card>

            <Text style={styles.sectionTitle}>SEGMENTS · HAZARDS · PREP</Text>
            {extras.loading && <LoadingState />}
            {extras.error && !extras.loading && (
              <ErrorState error={extras.error} onRetry={extras.refetch} />
            )}
            {extras.data ? (
              <View style={{ gap: sp.s3 }}>
                {extras.data.segments.length > 0 && (
                  <Card>
                    <Text style={styles.cardEyebrow}>SEGMENTS</Text>
                    {extras.data.segments.map((s) => (
                      <View key={`${s.km0}-${s.km1}`} style={styles.segRow}>
                        <View>
                          <Text style={styles.segName}>{s.name}</Text>
                          <Text style={styles.segMeta}>
                            {s.km0.toFixed(1)} – {s.km1.toFixed(1)} KM
                          </Text>
                        </View>
                        <DifficultyChip difficulty={s.diff} small />
                      </View>
                    ))}
                  </Card>
                )}
                {extras.data.hazards.length > 0 && (
                  <Card>
                    <Text style={styles.cardEyebrow}>HAZARDS</Text>
                    {extras.data.hazards.map((h, i) => (
                      <View key={i} style={styles.hazRow}>
                        <HazardGlyph kind={h.kind} variant="dot" />
                        <View style={{ flex: 1 }}>
                          <Text style={styles.segName}>{h.label}</Text>
                          {h.desc && <Text style={styles.segMeta} numberOfLines={2}>{h.desc}</Text>}
                        </View>
                        <Text style={styles.elevMeta}>{h.km.toFixed(1)} km</Text>
                      </View>
                    ))}
                  </Card>
                )}
                {extras.data.prep.water || extras.data.prep.startBy ? (
                  <Card>
                    <Text style={styles.cardEyebrow}>PREP</Text>
                    {prepFields(extras.data.prep).map((p) => (
                      <View key={p.label} style={styles.prepRow}>
                        <Text style={styles.prepLabel}>{p.label}</Text>
                        <Text style={styles.prepValue}>{p.value}</Text>
                      </View>
                    ))}
                  </Card>
                ) : null}
              </View>
            ) : (
              !extras.loading &&
              !extras.error && (
                <Text style={styles.noExtras}>
                  No editorial data for this trail yet. Add it via{' '}
                  <Text style={{ color: tt.ember }}>trail_metadata</Text> in Supabase.
                </Text>
              )
            )}

            <Pressable
              onPress={() =>
                router.push({ pathname: '/plan-route' })
              }
              style={({ pressed }) => [styles.cta, pressed && { opacity: 0.9 }]}
            >
              <Icon name="route" size={16} color="#1a0d04" strokeWidth={2.6} />
              <Text style={styles.ctaText}>PLAN THIS HIKE</Text>
            </Pressable>
          </>
        )}
      </ScrollView>
    </ScreenShell>
  );
}

function prepFields(prep: import('@/data/types').TrailPrep) {
  return [
    { label: 'Water', value: prep.water },
    { label: 'Food', value: prep.food },
    { label: 'Layers', value: prep.layers },
    { label: 'Safety', value: prep.safety },
    { label: 'Permit', value: prep.permit },
    { label: 'Start by', value: prep.startBy },
    { label: 'Turn around', value: prep.turnAround },
    { label: 'Cell signal', value: prep.cellSignal },
  ].filter((p) => p.value && p.value.length > 0);
}

function Stat({
  label,
  value,
  unit,
  ember,
}: {
  label: string;
  value: string;
  unit: string;
  ember?: boolean;
}) {
  return (
    <View style={styles.statCell}>
      <Text style={styles.statLabel}>{label}</Text>
      <View style={styles.statValueRow}>
        <Text style={[styles.statValue, ember && { color: tt.ember }]}>{value}</Text>
        <Text style={styles.statUnit}>{unit}</Text>
      </View>
    </View>
  );
}

function ElevationChart({ elev }: { elev: { km: number; metres: number }[] }) {
  const w = 320;
  const h = 110;
  const pad = 10;
  if (!elev || elev.length === 0) return <Text style={styles.empty}>No profile data.</Text>;
  const xs = elev.map((p) => p.km);
  const ys = elev.map((p) => p.metres);
  const minX = Math.min(...xs);
  const maxX = Math.max(...xs);
  const minY = Math.min(...ys);
  const maxY = Math.max(...ys);
  const sx = (x: number) => pad + ((x - minX) / Math.max(0.0001, maxX - minX)) * (w - pad * 2);
  const sy = (y: number) => h - pad - ((y - minY) / Math.max(1, maxY - minY)) * (h - pad * 2);
  const top = elev.map((p, i) => `${i === 0 ? 'M' : 'L'}${sx(p.km)},${sy(p.metres)}`).join(' ');
  const fill = `${top} L ${w - pad},${h - pad} L ${pad},${h - pad} Z`;
  return (
    <Svg width="100%" height={h} viewBox={`0 0 ${w} ${h}`} preserveAspectRatio="none">
      <Defs>
        <LinearGradient id="fxElev" x1="0" x2="0" y1="0" y2="1">
          <Stop offset="0%" stopColor={tt.ember} stopOpacity="0.55" />
          <Stop offset="100%" stopColor={tt.ember} stopOpacity="0" />
        </LinearGradient>
      </Defs>
      <Path d={fill} fill="url(#fxElev)" />
      <Path d={top} fill="none" stroke={tt.ember2} strokeWidth={1.8} strokeLinejoin="round" />
    </Svg>
  );
}

const styles = StyleSheet.create({
  body: { paddingHorizontal: sp.screen, paddingBottom: sp.s11 },
  headerRow: { flexDirection: 'row', alignItems: 'flex-start' },
  region: {
    fontFamily: font.uiBold,
    fontSize: 10.5,
    color: tt.text3,
    letterSpacing: ls.monoWide * 10.5,
    textTransform: 'uppercase',
  },
  title: {
    marginTop: 6,
    fontFamily: font.uiHeavy,
    fontSize: fz.cardTitle,
    color: tt.text,
    letterSpacing: ls.tight * fz.cardTitle,
  },
  statsBlock: { gap: sp.s2, marginLeft: sp.s5 },
  statCell: { alignItems: 'flex-end' },
  statLabel: {
    fontFamily: font.uiBold,
    fontSize: 9,
    color: tt.text3,
    letterSpacing: ls.monoWide * 9,
    textTransform: 'uppercase',
  },
  statValueRow: { flexDirection: 'row', alignItems: 'baseline', gap: 3 },
  statValue: {
    fontFamily: font.monoBold,
    fontSize: 16,
    color: tt.text,
    letterSpacing: ls.tight * 16,
  },
  statUnit: {
    fontFamily: font.monoSemi,
    fontSize: 10,
    color: tt.text2,
  },
  description: {
    marginTop: sp.s5,
    fontFamily: font.uiMed,
    fontSize: fz.body2,
    color: tt.text2,
    lineHeight: 19,
  },
  sectionTitle: {
    marginTop: sp.s8,
    marginBottom: sp.s3,
    fontFamily: font.uiBold,
    fontSize: 11,
    color: tt.text2,
    letterSpacing: ls.monoWide * 11,
    textTransform: 'uppercase',
  },
  elevRow: {
    marginTop: sp.s4,
    flexDirection: 'row',
    justifyContent: 'space-between',
  },
  elevMeta: {
    fontFamily: font.monoSemi,
    fontSize: fz.micro2,
    color: tt.text3,
    letterSpacing: ls.monoTight * fz.micro2,
  },
  empty: {
    padding: sp.s5,
    fontFamily: font.uiMed,
    fontSize: fz.body,
    color: tt.text3,
  },
  mapWrap: {
    height: 220,
    borderRadius: 14,
    overflow: 'hidden',
    borderWidth: 1,
    borderColor: tt.line,
    backgroundColor: tt.bg2,
  },
  cardEyebrow: {
    fontFamily: font.uiBold,
    fontSize: 10.5,
    color: tt.text3,
    letterSpacing: ls.monoWide * 10.5,
    textTransform: 'uppercase',
    marginBottom: sp.s4,
  },
  segRow: {
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    paddingVertical: sp.s3,
    borderTopWidth: 1,
    borderTopColor: tt.line,
  },
  segName: { fontFamily: font.uiBold, fontSize: fz.body2, color: tt.text },
  segMeta: {
    marginTop: 2,
    fontFamily: font.monoSemi,
    fontSize: fz.micro2,
    color: tt.text3,
    letterSpacing: ls.monoTight * fz.micro2,
  },
  hazRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: sp.s4,
    paddingVertical: sp.s3,
    borderTopWidth: 1,
    borderTopColor: tt.line,
  },
  prepRow: {
    flexDirection: 'row',
    justifyContent: 'space-between',
    gap: sp.s5,
    paddingVertical: sp.s2,
  },
  prepLabel: {
    fontFamily: font.monoBold,
    fontSize: 10,
    color: tt.text3,
    letterSpacing: ls.monoWide * 10,
    textTransform: 'uppercase',
    flex: 1,
  },
  prepValue: {
    flex: 2,
    fontFamily: font.uiSemi,
    fontSize: fz.body,
    color: tt.text,
    textAlign: 'right',
  },
  noExtras: {
    marginTop: sp.s4,
    fontFamily: font.uiMed,
    fontSize: fz.body,
    color: tt.text3,
  },
  cta: {
    marginTop: sp.s7,
    height: 54,
    borderRadius: 14,
    backgroundColor: tt.ember,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 10,
    ...shadow.ember,
  },
  ctaText: {
    fontFamily: font.uiHeavy,
    fontSize: fz.body2,
    letterSpacing: ls.monoWide * fz.body2,
    color: '#1a0d04',
  },
});
