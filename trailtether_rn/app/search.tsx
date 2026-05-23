// Trailtether — Search.
//
// Single search bar + scope ChipRow + grouped results. Trails come
// from the bundled `useTrailsCatalog()`; people, caves and reports
// are blocked (no person search, caves are pending #9 bundling, and
// reports use the same hazard reads we already have).

import React, { useMemo, useState } from 'react';
import {
  Pressable,
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
import { ErrorState, LoadingState } from '@components/primitives/States';
import { BlockedSection } from '@components/primitives/BlockedSection';
import { Icon } from '@components/Icon';
import { useTrailsCatalog, useFieldIntel, parseBlocked } from '@/data/hooks';
import { font, fz, ls, radius, sp, tt } from '@theme/tokens';

type Scope = 'all' | 'trails' | 'caves' | 'reports';

export default function SearchScreen() {
  const router = useRouter();
  const [q, setQ] = useState('');
  const [scope, setScope] = useState<Scope>('all');
  const trails = useTrailsCatalog();
  const reports = useFieldIntel();

  const trailMatches = useMemo(() => {
    if (!trails.data) return [];
    const lq = q.trim().toLowerCase();
    const filtered = lq
      ? trails.data.filter(
          (t) =>
            t.name.toLowerCase().includes(lq) ||
            t.region.toLowerCase().includes(lq),
        )
      : trails.data;
    return filtered.slice(0, 25);
  }, [trails.data, q]);

  const reportMatches = useMemo(() => {
    if (!reports.data) return [];
    const lq = q.trim().toLowerCase();
    const filtered = lq
      ? reports.data.filter(
          (r) =>
            r.title.toLowerCase().includes(lq) || r.sub.toLowerCase().includes(lq),
        )
      : reports.data;
    return filtered.slice(0, 25);
  }, [reports.data, q]);

  const showTrails = scope === 'all' || scope === 'trails';
  const showReports = scope === 'all' || scope === 'reports';
  const showCaves = scope === 'all' || scope === 'caves';
  const trailBlocked = parseBlocked(trails.error);

  return (
    <ScreenShell>
      <TTAppBar
        big
        title="Search"
        sub="TRAILS · CAVES · REPORTS"
        leftIcon="chevron-up"
        onPressLeft={() => router.back()}
        right={<IconBtn name="filter" />}
      />
      <View style={styles.body}>
        <View style={styles.searchWrap}>
          <Icon name="search" size={15} color={tt.text3} />
          <TextInput
            value={q}
            onChangeText={setQ}
            placeholder="Trail name, region, report keyword"
            placeholderTextColor={tt.text3}
            style={styles.searchInput}
            autoCapitalize="none"
            selectionColor={tt.ember}
            underlineColorAndroid="transparent"
          />
          {q.length > 0 && (
            <Pressable hitSlop={8} onPress={() => setQ('')}>
              <Icon name="plus" size={14} color={tt.text3} />
            </Pressable>
          )}
        </View>

        <View style={{ marginTop: sp.s4 }}>
          <ChipRow
            value={scope}
            onChange={(id) => setScope(id as Scope)}
            items={[
              {
                id: 'all',
                label: 'All',
                count: (trails.data?.length ?? 0) + (reports.data?.length ?? 0),
              },
              { id: 'trails', label: 'Trails', count: trails.data?.length ?? 0 },
              { id: 'caves', label: 'Caves' },
              { id: 'reports', label: 'Reports', count: reports.data?.length ?? 0 },
            ]}
          />
        </View>

        {showTrails && (
          <View style={styles.section}>
            <Text style={styles.heading}>Trails</Text>
            {trails.loading && <LoadingState />}
            {trailBlocked && (
              <BlockedSection
                number={trailBlocked.n}
                title="Trail catalog isn't bundled yet"
                note={trailBlocked.reason}
              />
            )}
            {!trails.loading && !trailBlocked && trails.error && (
              <ErrorState error={trails.error} onRetry={trails.refetch} />
            )}
            {trails.data &&
              trailMatches.map((t) => (
                <Card
                  key={t.id}
                  tight
                  onPress={() => router.push({ pathname: '/trail-detail', params: { id: t.id } })}
                  style={{ marginTop: sp.s3 }}
                >
                  <View style={styles.row}>
                    <View style={{ flex: 1 }}>
                      <Text style={styles.trailName} numberOfLines={1}>
                        {t.name}
                      </Text>
                      <Text style={styles.trailMeta} numberOfLines={1}>
                        {t.region.toUpperCase()} · {t.distanceKm.toFixed(1)} KM · ↑{t.ascentM} M
                      </Text>
                    </View>
                    <View style={{ alignItems: 'flex-end', gap: 6 }}>
                      <DifficultyChip difficulty={t.difficulty} small />
                      <Icon name="chevron-right" size={14} color={tt.text3} />
                    </View>
                  </View>
                </Card>
              ))}
          </View>
        )}

        {showCaves && (
          <View style={styles.section}>
            <Text style={styles.heading}>Caves</Text>
            <BlockedSection
              number={9}
              title="125 surveyed caves pending bundle"
              note="caves.gpx ships via the same routes bundle in BLOCKERS.md #9."
            />
          </View>
        )}

        {showReports && (
          <View style={styles.section}>
            <Text style={styles.heading}>Field reports</Text>
            {reports.loading && <LoadingState />}
            {reports.error && !reports.loading && (
              <ErrorState error={reports.error} onRetry={reports.refetch} />
            )}
            {reports.data &&
              reportMatches.map((r) => (
                <Card key={r.id} tight style={{ marginTop: sp.s3 }}>
                  <View style={styles.row}>
                    <View style={[styles.reportDot, { backgroundColor: riskColor(r.risk) }]} />
                    <View style={{ flex: 1 }}>
                      <Text style={styles.trailName} numberOfLines={1}>
                        {r.title}
                      </Text>
                      <Text style={styles.trailMeta} numberOfLines={2}>
                        {r.sub}
                      </Text>
                    </View>
                    <Text style={styles.timeLabel}>{r.timeLabel}</Text>
                  </View>
                </Card>
              ))}
          </View>
        )}
      </View>
    </ScreenShell>
  );
}

function riskColor(r: 'low' | 'moderate' | 'high' | 'info'): string {
  switch (r) {
    case 'high':
      return tt.red;
    case 'moderate':
      return tt.amber;
    case 'low':
      return tt.green;
    default:
      return tt.blue;
  }
}

const styles = StyleSheet.create({
  body: { paddingHorizontal: sp.screen },
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
  section: { marginTop: sp.s8 },
  heading: {
    fontFamily: font.uiBold,
    fontSize: 11,
    color: tt.text2,
    letterSpacing: ls.monoWide * 11,
    textTransform: 'uppercase',
    marginBottom: sp.s3,
  },
  row: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: sp.s5,
  },
  trailName: {
    fontFamily: font.uiBold,
    fontSize: fz.rowTitle,
    color: tt.text,
  },
  trailMeta: {
    marginTop: 2,
    fontFamily: font.monoSemi,
    fontSize: fz.micro2,
    color: tt.text3,
    letterSpacing: ls.monoTight * fz.micro2,
  },
  reportDot: {
    width: 10,
    height: 10,
    borderRadius: 5,
    marginTop: 2,
  },
  timeLabel: {
    fontFamily: font.monoBold,
    fontSize: 10,
    color: tt.text3,
    letterSpacing: ls.monoTight * 10,
  },
});
