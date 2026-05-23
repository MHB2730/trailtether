// Trailtether — Achievements (full grid).
//
// Walks the full ACHIEVEMENTS_CATALOG and renders a 4-column grid of
// topographic medallions, grouped by rarity. Unlock state for the 5
// deterministic catalog ids comes from `v_user_achievement_progress`
// (BLOCKERS #5 partial). The remaining ids stay locked and surface a
// "more unlocks coming" banner.

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
import { AchievementMedallion } from '@components/design/AchievementMedallion';
import { BlockedSection } from '@components/primitives/BlockedSection';
import { ErrorState, LoadingState } from '@components/primitives/States';
import { useAchievements } from '@/data/hooks';
import { font, fz, ls, rarityColor, sp, tt, type Rarity } from '@theme/tokens';

const RARITY_ORDER: Rarity[] = ['legendary', 'epic', 'rare', 'common'];

export default function AchievementsScreen() {
  const router = useRouter();
  const ach = useAchievements();

  const grouped = useMemo(() => {
    if (!ach.data) return null;
    const out: Record<Rarity, typeof ach.data.catalog> = {
      common: [],
      rare: [],
      epic: [],
      legendary: [],
    };
    for (const a of ach.data.catalog) out[a.rarity].push(a);
    return out;
  }, [ach.data]);

  const unlocked = ach.data?.unlockedCount ?? 0;
  const total = ach.data?.catalog.length ?? 0;

  return (
    <ScreenShell>
      <TTAppBar
        big
        title="Achievements"
        sub={total > 0 ? `${unlocked} / ${total} UNLOCKED` : 'HEXAGONAL SURVEY MARKERS'}
        leftIcon="chevron-up"
        onPressLeft={() => router.back()}
        right={<IconBtn name="filter" />}
      />
      <ScrollView
        contentContainerStyle={styles.body}
        showsVerticalScrollIndicator={false}
      >
        {ach.loading && <LoadingState />}
        {ach.error && !ach.loading && (
          <ErrorState error={ach.error} onRetry={ach.refetch} />
        )}
        {ach.data?.partial && (
          <BlockedSection
            number={5}
            title={`${ach.data.partial.pendingCount} medallions need derived signals`}
            note="Unlocks for first / gpx / highrise / 5k / centurion derive from hike_history today. The rest need weather / region / time-of-day correlation."
          />
        )}

        {grouped &&
          RARITY_ORDER.map((rarity) => {
            const list = grouped[rarity];
            if (list.length === 0) return null;
            const spec = rarityColor(rarity);
            return (
              <View key={rarity} style={styles.section}>
                <View style={styles.sectionHeader}>
                  <View style={[styles.rarityDot, { backgroundColor: spec.ring }]} />
                  <Text style={[styles.sectionTitle, { color: spec.ring }]}>
                    {spec.label}
                  </Text>
                  <Text style={styles.sectionCount}>{list.length}</Text>
                </View>
                <View style={styles.grid}>
                  {list.map((a) => (
                    <View
                      key={a.id}
                      style={[styles.cell, a.unlocked && styles.cellUnlocked]}
                    >
                      <AchievementMedallion
                        id={a.id}
                        icon={a.iconName}
                        rarity={a.rarity}
                        unlocked={a.unlocked}
                        progress={a.progress}
                        size={56}
                      />
                      <Text
                        style={[styles.label, a.unlocked && { color: tt.text }]}
                        numberOfLines={2}
                      >
                        {a.label}
                      </Text>
                      <Text style={styles.sub} numberOfLines={2}>
                        {a.unlocked
                          ? 'UNLOCKED'
                          : a.progress > 0
                            ? `${Math.round(a.progress * 100)}%`
                            : a.sub}
                      </Text>
                    </View>
                  ))}
                </View>
              </View>
            );
          })}
      </ScrollView>
    </ScreenShell>
  );
}

const styles = StyleSheet.create({
  body: { paddingHorizontal: sp.screen, paddingBottom: sp.s11 },
  section: { marginTop: sp.s8 },
  sectionHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: sp.s3,
    marginBottom: sp.s4,
  },
  rarityDot: { width: 8, height: 8, borderRadius: 4 },
  sectionTitle: {
    fontFamily: font.monoBold,
    fontSize: 11,
    letterSpacing: ls.monoWide * 11,
  },
  sectionCount: {
    marginLeft: 'auto',
    fontFamily: font.monoSemi,
    fontSize: 10,
    color: tt.text3,
    letterSpacing: ls.monoTight * 10,
  },
  grid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: sp.s3,
  },
  cell: {
    width: '22.5%',
    alignItems: 'center',
    padding: sp.s3,
    backgroundColor: tt.surf,
    borderRadius: 11,
    borderWidth: 1,
    borderColor: tt.line,
  },
  cellUnlocked: {
    borderColor: 'rgba(255,106,44,0.45)',
    backgroundColor: tt.emberSoft,
  },
  label: {
    marginTop: 7,
    fontFamily: font.uiHeavy,
    fontSize: 9.5,
    color: tt.text,
    textAlign: 'center',
  },
  sub: {
    marginTop: 2,
    fontFamily: font.uiMed,
    fontSize: 8.5,
    color: tt.text3,
    textAlign: 'center',
  },
});

void fz;
