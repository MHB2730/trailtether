// Trailtether — Hike History.
//
// Time-window filter chips → list of hike records from `hike_history`.
// Letter-grade chips ("A", "B", …) come from BLOCKERS.md #11 so they
// show "—" today. Each row navigates to a Trail Detail when the
// recording was linked to a catalog trail.

import React, { useMemo, useState } from 'react';
import {
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { ScreenShell } from '@components/primitives/ScreenShell';
import { TTAppBar, IconBtn } from '@components/primitives/TTAppBar';
import { Card } from '@components/primitives/Card';
import { ChipRow } from '@components/design/ChipRow';
import { DifficultyChip } from '@components/primitives/Pill';
import { ErrorState, LoadingState } from '@components/primitives/States';
import { Icon } from '@components/Icon';
import { useHikeHistory } from '@/data/hooks';
import { hoursMinutesLabel, shortDateLabel, thousandsLabel } from '@/data/adapters';
import { font, fz, ls, sp, tt } from '@theme/tokens';

type Window = 'all' | 'month' | '90d';

export default function HistoryScreen() {
  const router = useRouter();
  const history = useHikeHistory();
  const [window, setWindow] = useState<Window>('all');

  const filtered = useMemo(() => {
    if (!history.data) return [];
    if (window === 'all') return history.data;
    const cutoff = new Date();
    if (window === 'month') cutoff.setDate(cutoff.getDate() - 31);
    else cutoff.setDate(cutoff.getDate() - 90);
    return history.data.filter((h) => h.createdAt >= cutoff);
  }, [history.data, window]);

  const totals = useMemo(() => {
    if (!filtered.length) {
      return { distance: 0, ascent: 0, count: 0 };
    }
    let distance = 0;
    let ascent = 0;
    for (const h of filtered) {
      distance += h.distanceKm;
      ascent += h.ascentM;
    }
    return { distance, ascent, count: filtered.length };
  }, [filtered]);

  return (
    <ScreenShell>
      <TTAppBar
        big
        title="Hike History"
        sub="GPX RECORDINGS"
        leftIcon="chevron-up"
        onPressLeft={() => router.back()}
        right={<IconBtn name="filter" />}
      />
      <ScrollView
        contentContainerStyle={styles.body}
        showsVerticalScrollIndicator={false}
      >
        <Card>
          <Text style={styles.heroLabel}>WINDOW TOTALS</Text>
          <View style={styles.heroRow}>
            <View>
              <Text style={styles.heroValue}>{totals.count}</Text>
              <Text style={styles.heroUnit}>HIKES</Text>
            </View>
            <View>
              <Text style={styles.heroValue}>{totals.distance.toFixed(1)}</Text>
              <Text style={styles.heroUnit}>KM</Text>
            </View>
            <View>
              <Text style={[styles.heroValue, { color: tt.ember }]}>
                {thousandsLabel(totals.ascent)}
              </Text>
              <Text style={styles.heroUnit}>M ASCENT</Text>
            </View>
          </View>
        </Card>

        <View style={{ marginTop: sp.s5 }}>
          <ChipRow
            fitted
            value={window}
            onChange={(id) => setWindow(id as Window)}
            items={[
              { id: 'all', label: 'All' },
              { id: 'month', label: 'Month' },
              { id: '90d', label: '90 days' },
            ]}
          />
        </View>

        {history.loading && <LoadingState style={{ marginTop: sp.s6 }} />}
        {history.error && !history.loading && (
          <ErrorState error={history.error} onRetry={history.refetch} />
        )}

        {!history.loading && !history.error && (
          <View style={{ marginTop: sp.s4 }}>
            {filtered.length === 0 && (
              <Text style={styles.empty}>No recorded hikes in this window.</Text>
            )}
            {filtered.map((h) => (
              <Pressable
                key={h.id}
                onPress={() => router.push('/stats')}
                style={({ pressed }) => [pressed && { opacity: 0.85 }]}
              >
                <Card tight style={{ marginTop: sp.s3 }}>
                  <View style={styles.row}>
                    <View style={{ flex: 1, minWidth: 0 }}>
                      <Text style={styles.title} numberOfLines={1}>
                        {h.name}
                      </Text>
                      <Text style={styles.meta} numberOfLines={1}>
                        {shortDateLabel(h.createdAt)} · {h.distanceKm.toFixed(1)} KM ·{' '}
                        {hoursMinutesLabel(h.durationSeconds)}
                      </Text>
                    </View>
                    <View style={{ alignItems: 'flex-end', gap: 6 }}>
                      {h.difficulty && <DifficultyChip difficulty={h.difficulty} small />}
                      <View style={styles.gradeChip}>
                        <Text style={styles.gradeText}>{h.score ?? '—'}</Text>
                      </View>
                    </View>
                    <Icon name="chevron-right" size={14} color={tt.text3} />
                  </View>
                </Card>
              </Pressable>
            ))}
          </View>
        )}
      </ScrollView>
    </ScreenShell>
  );
}

const styles = StyleSheet.create({
  body: { paddingHorizontal: sp.screen, paddingBottom: sp.s11 },
  heroLabel: {
    fontFamily: font.uiBold,
    fontSize: 10.5,
    color: tt.text3,
    letterSpacing: ls.monoWide * 10.5,
    textTransform: 'uppercase',
  },
  heroRow: {
    marginTop: sp.s4,
    flexDirection: 'row',
    gap: sp.s9,
  },
  heroValue: {
    fontFamily: font.uiHeavy,
    fontSize: fz.hero2,
    color: tt.text,
    letterSpacing: ls.tight * fz.hero2,
  },
  heroUnit: {
    marginTop: 2,
    fontFamily: font.monoBold,
    fontSize: 9.5,
    color: tt.text3,
    letterSpacing: ls.monoWide * 9.5,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: sp.s5,
  },
  title: {
    fontFamily: font.uiBold,
    fontSize: fz.rowTitle,
    color: tt.text,
  },
  meta: {
    marginTop: 2,
    fontFamily: font.monoSemi,
    fontSize: fz.micro2,
    color: tt.text3,
    letterSpacing: ls.monoTight * fz.micro2,
  },
  gradeChip: {
    minWidth: 26,
    paddingHorizontal: 6,
    paddingVertical: 2,
    borderRadius: 6,
    backgroundColor: tt.emberDim,
    borderWidth: 1,
    borderColor: 'rgba(255,106,44,0.45)',
    alignItems: 'center',
  },
  gradeText: {
    fontFamily: font.monoBold,
    fontSize: 11,
    color: tt.ember,
  },
  empty: {
    textAlign: 'center',
    marginTop: sp.s9,
    fontFamily: font.uiMed,
    fontSize: fz.body,
    color: tt.text3,
  },
});
