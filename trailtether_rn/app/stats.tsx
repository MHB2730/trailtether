// Trailtether — Stats.
//
// Aggregates the user's full `hike_history` into the four headline
// stat cards from the design + lifetime totals. The richer "weekly
// rollup" + "monthly trend" charts are pending the materialised
// view referenced in BLOCKERS.md #5.

import React, { useMemo } from 'react';
import {
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { ScreenShell } from '@components/primitives/ScreenShell';
import { TTAppBar, IconBtn } from '@components/primitives/TTAppBar';
import { Card } from '@components/primitives/Card';
import { BlockedSection } from '@components/primitives/BlockedSection';
import { ErrorState, LoadingState } from '@components/primitives/States';
import { Icon } from '@components/Icon';
import { useHikeHistory, useProfileStats } from '@/data/hooks';
import { hoursMinutesLabel, thousandsLabel } from '@/data/adapters';
import { font, fz, ls, sp, tt } from '@theme/tokens';

export default function StatsScreen() {
  const router = useRouter();
  const history = useHikeHistory();
  const stats = useProfileStats();

  const totals = useMemo(() => {
    if (!history.data) return null;
    let dist = 0;
    let ascent = 0;
    let seconds = 0;
    for (const h of history.data) {
      dist += h.distanceKm;
      ascent += h.ascentM;
      seconds += h.durationSeconds;
    }
    return { dist, ascent, seconds, count: history.data.length };
  }, [history.data]);

  return (
    <ScreenShell>
      <TTAppBar
        big
        title="Stats"
        sub="LIFETIME · WEEKLY · TRENDS"
        leftIcon="chevron-up"
        onPressLeft={() => router.back()}
        right={<IconBtn name="filter" />}
      />
      <ScrollView
        contentContainerStyle={styles.body}
        showsVerticalScrollIndicator={false}
      >
        {(history.loading || stats.loading) && <LoadingState />}
        {(history.error || stats.error) && (
          <ErrorState
            error={history.error ?? stats.error}
            onRetry={() => {
              void history.refetch();
              void stats.refetch();
            }}
          />
        )}

        {totals && (
          <Card>
            <Text style={styles.heroLabel}>LIFETIME</Text>
            <Text style={styles.hero}>{totals.count}</Text>
            <Text style={styles.heroSub}>
              hikes · {totals.dist.toFixed(1)} km · ↑{thousandsLabel(totals.ascent)} m ·{' '}
              {hoursMinutesLabel(totals.seconds)} h
            </Text>
          </Card>
        )}

        {stats.data && stats.data.length > 0 && (
          <View style={styles.grid}>
            {stats.data.map((s) => (
              <Card
                key={s.label}
                tight
                padding={{ paddingVertical: sp.s6, paddingHorizontal: sp.s6 }}
                style={styles.cell}
              >
                <View style={styles.statHeader}>
                  <Icon name={s.iconName} size={12} color={s.ember ? tt.ember : tt.text3} />
                  <Text style={styles.statLabel}>{s.label}</Text>
                </View>
                <View style={styles.valueRow}>
                  <Text style={[styles.statValue, s.ember && { color: tt.ember }]}>
                    {s.value}
                  </Text>
                  {s.unit && <Text style={styles.statUnit}>{s.unit}</Text>}
                </View>
              </Card>
            ))}
          </View>
        )}

        <View style={{ marginTop: sp.s7 }}>
          <BlockedSection
            number={5}
            title="Weekly + monthly trends pending"
            note="Materialised hike_history rollups land with the same migration as achievements."
          />
        </View>
      </ScrollView>
    </ScreenShell>
  );
}

const styles = StyleSheet.create({
  body: { paddingHorizontal: sp.screen, paddingBottom: sp.s11 },
  heroLabel: {
    fontFamily: font.uiBold,
    fontSize: 11,
    color: tt.text3,
    letterSpacing: ls.monoWide * 11,
    textTransform: 'uppercase',
  },
  hero: {
    marginTop: 4,
    fontFamily: font.uiHeavy,
    fontSize: fz.heroNum,
    color: tt.text,
    letterSpacing: ls.tight * fz.heroNum,
  },
  heroSub: {
    marginTop: 2,
    fontFamily: font.monoSemi,
    fontSize: fz.body,
    color: tt.text2,
    letterSpacing: ls.monoTight * fz.body,
  },
  grid: {
    marginTop: sp.s6,
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: sp.s4,
  },
  cell: { width: '47%' },
  statHeader: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  statLabel: {
    fontFamily: font.uiBold,
    fontSize: 9.5,
    color: tt.text3,
    letterSpacing: ls.monoWide * 9.5,
    textTransform: 'uppercase',
  },
  valueRow: {
    flexDirection: 'row',
    alignItems: 'baseline',
    gap: 4,
    marginTop: 8,
  },
  statValue: {
    fontFamily: font.monoBold,
    fontSize: 22,
    color: tt.text,
    letterSpacing: ls.tight * 22,
  },
  statUnit: {
    fontFamily: font.monoSemi,
    fontSize: 11,
    color: tt.text2,
  },
});
