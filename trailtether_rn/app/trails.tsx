// Trailtether — Trails (catalog list).
//
// Difficulty filter ChipRow + list of trails. Reads from the bundled
// `routes_cleaned.json` via `useTrailsCatalog()`. When the bundle is
// missing (BLOCKERS.md #9) we surface that explicitly.

import React, { useMemo, useState } from 'react';
import {
  ScrollView,
  StyleSheet,
  Text,
  TextInput,
  View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { ScreenShell } from '@components/primitives/ScreenShell';
import { TTAppBar, IconBtn } from '@components/primitives/TTAppBar';
import { Card } from '@components/primitives/Card';
import { ChipRow } from '@components/design/ChipRow';
import { DifficultyChip } from '@components/primitives/Pill';
import { BlockedSection } from '@components/primitives/BlockedSection';
import { ErrorState, LoadingState } from '@components/primitives/States';
import { Icon } from '@components/Icon';
import { useTrailsCatalog, parseBlocked } from '@/data/hooks';
import { font, fz, ls, radius, sp, tt } from '@theme/tokens';

type DiffFilter = 'all' | 'easy' | 'moderate' | 'difficult' | 'technical';

export default function TrailsScreen() {
  const router = useRouter();
  const trails = useTrailsCatalog();
  const [filter, setFilter] = useState<DiffFilter>('all');
  const [q, setQ] = useState('');
  const blocked = parseBlocked(trails.error);

  const filtered = useMemo(() => {
    if (!trails.data) return [];
    const lq = q.trim().toLowerCase();
    return trails.data.filter((t) => {
      if (filter !== 'all' && t.difficulty !== filter) return false;
      if (lq && !t.name.toLowerCase().includes(lq) && !t.region.toLowerCase().includes(lq))
        return false;
      return true;
    });
  }, [trails.data, filter, q]);

  return (
    <ScreenShell>
      <TTAppBar
        big
        title="Trails"
        sub={trails.data ? `${trails.data.length} ROUTES SURVEYED` : 'CATALOG'}
        leftIcon="chevron-up"
        onPressLeft={() => router.back()}
        right={<IconBtn name="filter" />}
      />
      <ScrollView
        contentContainerStyle={styles.body}
        showsVerticalScrollIndicator={false}
      >
        <View style={styles.searchWrap}>
          <Icon name="search" size={15} color={tt.text3} />
          <TextInput
            value={q}
            onChangeText={setQ}
            placeholder="Filter by name or region"
            placeholderTextColor={tt.text3}
            style={styles.searchInput}
            autoCapitalize="none"
            selectionColor={tt.ember}
            underlineColorAndroid="transparent"
          />
        </View>

        <View style={{ marginTop: sp.s4 }}>
          <ChipRow
            value={filter}
            onChange={(id) => setFilter(id as DiffFilter)}
            items={[
              { id: 'all', label: 'All' },
              { id: 'easy', label: 'Easy' },
              { id: 'moderate', label: 'Moderate' },
              { id: 'difficult', label: 'Difficult' },
              { id: 'technical', label: 'Technical' },
            ]}
          />
        </View>

        {trails.loading && <LoadingState style={{ marginTop: sp.s6 }} />}
        {blocked && (
          <BlockedSection
            number={blocked.n}
            title="Trail catalog isn't bundled yet"
            note={blocked.reason}
          />
        )}
        {!trails.loading && !blocked && trails.error && (
          <ErrorState error={trails.error} onRetry={trails.refetch} />
        )}

        {filtered.length === 0 && !trails.loading && !trails.error && (
          <Text style={styles.empty}>No trails match those filters.</Text>
        )}

        {filtered.map((t) => (
          <Card
            key={t.id}
            tight
            onPress={() => router.push({ pathname: '/trail-detail', params: { id: t.id } })}
            style={{ marginTop: sp.s3 }}
          >
            <View style={styles.row}>
              <View style={{ flex: 1, minWidth: 0 }}>
                <Text style={styles.name} numberOfLines={1}>
                  {t.name}
                </Text>
                <Text style={styles.meta} numberOfLines={1}>
                  {t.region.toUpperCase()} · {t.distanceKm.toFixed(1)} KM · ↑
                  {t.ascentM} M · {t.hoursLabel} HRS
                </Text>
              </View>
              <View style={{ alignItems: 'flex-end', gap: 6 }}>
                <DifficultyChip difficulty={t.difficulty} small />
                <Icon name="chevron-right" size={14} color={tt.text3} />
              </View>
            </View>
          </Card>
        ))}
      </ScrollView>
    </ScreenShell>
  );
}

const styles = StyleSheet.create({
  body: { paddingHorizontal: sp.screen, paddingBottom: sp.s11 },
  searchWrap: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: sp.s4,
    paddingHorizontal: sp.s6,
    paddingVertical: sp.s4,
    backgroundColor: tt.surf,
    borderWidth: 1,
    borderColor: tt.line2,
    borderRadius: radius.md,
  },
  searchInput: {
    flex: 1,
    fontFamily: font.uiSemi,
    fontSize: fz.body2,
    color: tt.text,
    paddingVertical: 0,
  },
  row: { flexDirection: 'row', alignItems: 'center', gap: sp.s5 },
  name: { fontFamily: font.uiBold, fontSize: fz.rowTitle, color: tt.text },
  meta: {
    marginTop: 2,
    fontFamily: font.monoSemi,
    fontSize: fz.micro2,
    color: tt.text3,
    letterSpacing: ls.monoTight * fz.micro2,
  },
  empty: {
    marginTop: sp.s8,
    textAlign: 'center',
    fontFamily: font.uiMed,
    fontSize: fz.body,
    color: tt.text3,
  },
});
