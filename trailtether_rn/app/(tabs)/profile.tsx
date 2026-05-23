// Trailtether — Profile (tab).
//
// Avatar header + four stat tiles + achievement grid + small
// settings list. Stats come from useProfileStats(); achievements
// from the catalog + per-user progress (blocked, BLOCKERS.md #5).
//
// Header avatar uses initialsFromName + colorForUid so the same user
// always gets the same accent across the app (matches the design's
// avatar palette).

import React from 'react';
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
import { AchievementMedallion } from '@components/design/AchievementMedallion';
import { SettingRow, SettingsGroup } from '@components/design/SettingRow';
import { ErrorState, LoadingState } from '@components/primitives/States';
import { Icon, type IconName } from '@components/Icon';
import { useAchievements, useProfileStats } from '@/data/hooks';
import { useAuth, selectDisplayName } from '@/store/auth';
import { colorForUid, initialsFromName } from '@/data/adapters';
import { font, fz, ls, radius, sp, tt } from '@theme/tokens';

export default function ProfileTab() {
  const router = useRouter();
  const profile = useAuth((s) => s.profile);
  const userId = useAuth((s) => s.user?.id);
  const email = useAuth((s) => s.user?.email);
  const displayName = useAuth(selectDisplayName);
  const fullName = profile?.display_name?.trim() || displayName;
  const accent = colorForUid(userId ?? fullName);
  const initials = initialsFromName(fullName);

  const stats = useProfileStats();
  const ach = useAchievements();

  return (
    <ScreenShell>
      <TTAppBar
        sub="HIKER · PROFILE"
        right={
          <View style={{ flexDirection: 'row', gap: sp.s2 }}>
            <IconBtn name="search" onPress={() => router.push('/search')} />
            <IconBtn name="settings" onPress={() => router.push('/settings')} />
          </View>
        }
      />
      <ScrollView
        contentContainerStyle={styles.body}
        showsVerticalScrollIndicator={false}
      >
        <Card padding={{ paddingVertical: sp.s8, paddingHorizontal: sp.s7 }}>
          <View style={styles.headerRow}>
            <View style={[styles.avatar, { backgroundColor: accent }]}>
              <Text style={styles.avatarText}>{initials}</Text>
            </View>
            <View style={{ flex: 1, minWidth: 0 }}>
              <Text style={styles.name} numberOfLines={1}>
                {fullName}
              </Text>
              <Text style={styles.handle} numberOfLines={1}>
                {profile?.username ? `@${profile.username}` : email ?? '—'}
              </Text>
              {profile?.region && (
                <Text style={styles.region} numberOfLines={1}>
                  {profile.region.toUpperCase()}
                </Text>
              )}
              <View style={styles.badges}>
                <View style={[styles.badge, { backgroundColor: tt.emberDim, borderColor: 'rgba(255,106,44,0.45)' }]}>
                  <Text style={[styles.badgeText, { color: tt.ember }]}>TETHERED</Text>
                </View>
                {profile?.experience_level && (
                  <View
                    style={[
                      styles.badge,
                      { backgroundColor: 'rgba(90,161,214,0.15)', borderColor: 'rgba(90,161,214,0.45)' },
                    ]}
                  >
                    <Text style={[styles.badgeText, { color: tt.blue }]}>
                      {profile.experience_level.toUpperCase()}
                    </Text>
                  </View>
                )}
                {profile?.is_admin && (
                  <View
                    style={[
                      styles.badge,
                      {
                        backgroundColor: 'rgba(242,169,59,0.15)',
                        borderColor: 'rgba(242,169,59,0.45)',
                      },
                    ]}
                  >
                    <Text style={[styles.badgeText, { color: tt.amber }]}>ADMIN</Text>
                  </View>
                )}
              </View>
            </View>
            <Pressable
              onPress={() => router.push('/edit-profile')}
              hitSlop={6}
              style={({ pressed }) => [styles.editBtn, pressed && { opacity: 0.7 }]}
            >
              <Icon name="user" size={14} color={tt.ember} />
            </Pressable>
          </View>
          {profile?.bio && (
            <Text style={styles.bio} numberOfLines={4}>
              {profile.bio}
            </Text>
          )}
        </Card>

        <View style={styles.statsGrid}>
          {stats.loading && <LoadingState style={{ marginTop: sp.s5 }} />}
          {stats.error && !stats.loading && (
            <ErrorState error={stats.error} onRetry={stats.refetch} />
          )}
          {stats.data?.map((s) => (
            <Card
              key={s.label}
              tight
              padding={{ paddingVertical: sp.s6, paddingHorizontal: sp.s6 }}
              style={styles.statCard}
            >
              <View style={styles.statHeader}>
                <Icon name={s.iconName} size={12} color={s.ember ? tt.ember : tt.text3} />
                <Text style={styles.statLabel}>{s.label}</Text>
              </View>
              <View style={styles.statValueRow}>
                <Text style={[styles.statValue, s.ember && { color: tt.ember }]}>
                  {s.value}
                </Text>
                {s.unit && <Text style={styles.statUnit}>{s.unit}</Text>}
              </View>
            </Card>
          ))}
        </View>

        <View style={styles.sectionHeader}>
          <Text style={styles.sectionTitle}>
            ACHIEVEMENTS{' '}
            {ach.data && (
              <Text style={{ color: tt.text3 }}>
                ({ach.data.unlockedCount}/{ach.data.catalog.length})
              </Text>
            )}
          </Text>
          <Pressable onPress={() => router.push('/achievements')} hitSlop={6}>
            <Text style={styles.viewAll}>VIEW ALL →</Text>
          </Pressable>
        </View>

        {ach.loading && <LoadingState />}
        {ach.error && !ach.loading && <ErrorState error={ach.error} onRetry={ach.refetch} />}
        {ach.data && (
          <View style={styles.achGrid}>
            {ach.data.catalog.slice(0, 8).map((a) => (
              <View
                key={a.id}
                style={[styles.achCell, a.unlocked && styles.achCellUnlocked]}
              >
                <AchievementMedallion
                  id={a.id}
                  icon={a.iconName as IconName}
                  rarity={a.rarity}
                  unlocked={a.unlocked}
                  progress={a.progress}
                  size={56}
                />
                <Text
                  style={[styles.achLabel, a.unlocked && { color: tt.text }]}
                  numberOfLines={1}
                >
                  {a.label}
                </Text>
              </View>
            ))}
          </View>
        )}

        <SettingsGroup title="Quick links">
          <SettingRow
            icon="history"
            label="Hike history"
            sub="Recent recordings + GPX export"
            onPress={() => router.push('/history')}
          />
          <SettingRow
            icon="mountain"
            label="Stats"
            sub="Distance, ascent, peaks"
            onPress={() => router.push('/stats')}
          />
          <SettingRow
            icon="settings"
            label="Settings"
            sub="Account, privacy, tether"
            isLast
            onPress={() => router.push('/settings')}
          />
        </SettingsGroup>
      </ScrollView>
    </ScreenShell>
  );
}

const styles = StyleSheet.create({
  body: { paddingHorizontal: sp.screen, paddingBottom: sp.s11 },
  headerRow: { flexDirection: 'row', alignItems: 'center', gap: sp.s6 },
  avatar: {
    width: 64,
    height: 64,
    borderRadius: 32,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: {
    fontFamily: font.uiHeavy,
    fontSize: 22,
    color: '#1a0d04',
    letterSpacing: ls.tight * 22,
  },
  name: {
    fontFamily: font.uiHeavy,
    fontSize: fz.cardTitle,
    color: tt.text,
  },
  handle: {
    marginTop: 2,
    fontFamily: font.monoSemi,
    fontSize: fz.micro2,
    color: tt.text3,
    letterSpacing: ls.monoTight * fz.micro2,
  },
  region: {
    marginTop: 4,
    fontFamily: font.monoBold,
    fontSize: 9.5,
    color: tt.text2,
    letterSpacing: ls.monoWide * 9.5,
  },
  bio: {
    marginTop: sp.s5,
    fontFamily: font.uiMed,
    fontSize: fz.body,
    color: tt.text2,
    lineHeight: 18,
  },
  badges: { flexDirection: 'row', gap: 6, marginTop: 6, flexWrap: 'wrap' },
  badge: {
    paddingVertical: 2,
    paddingHorizontal: 7,
    borderRadius: 5,
    borderWidth: 1,
  },
  badgeText: {
    fontFamily: font.monoBold,
    fontSize: 8.5,
    letterSpacing: ls.monoWide * 8.5,
  },
  editBtn: {
    width: 34,
    height: 34,
    borderRadius: 9,
    backgroundColor: tt.emberDim,
    borderWidth: 1,
    borderColor: 'rgba(255,106,44,0.45)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  statsGrid: {
    marginTop: sp.s6,
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: sp.s4,
  },
  statCard: { width: '47%' },
  statHeader: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  statLabel: {
    fontFamily: font.uiBold,
    fontSize: 9.5,
    color: tt.text3,
    letterSpacing: ls.monoWide * 9.5,
    textTransform: 'uppercase',
  },
  statValueRow: {
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
  sectionHeader: {
    marginTop: sp.s9,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'space-between',
    marginBottom: sp.s4,
  },
  sectionTitle: {
    fontFamily: font.uiBold,
    fontSize: 11,
    color: tt.text2,
    letterSpacing: ls.monoWide * 11,
    textTransform: 'uppercase',
  },
  viewAll: {
    fontFamily: font.uiHeavy,
    fontSize: 10,
    color: tt.ember,
    letterSpacing: ls.monoMed * 10,
  },
  achGrid: {
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: sp.s3,
    marginTop: sp.s2,
  },
  achCell: {
    width: '22%',
    alignItems: 'center',
    paddingVertical: sp.s4,
    paddingHorizontal: 2,
    backgroundColor: tt.surf,
    borderRadius: 11,
    borderWidth: 1,
    borderColor: tt.line,
  },
  achCellUnlocked: {
    borderColor: 'rgba(255,106,44,0.45)',
    backgroundColor: tt.emberSoft,
  },
  achLabel: {
    marginTop: 7,
    fontFamily: font.uiHeavy,
    fontSize: 9.5,
    color: tt.text3,
    textAlign: 'center',
  },
});

void radius;
