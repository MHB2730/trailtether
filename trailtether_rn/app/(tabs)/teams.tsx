// Trailtether — Teams (tab).
//
// Lists the user's teams, lets them pick one, then renders the live
// member rollcall: avatar, last-seen, altitude, battery + connectivity.
// All powered by `useMyTeams()` + `useTeamMembers(teamId)`.

import React, { useEffect, useState } from 'react';
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
import { BlockedSection } from '@components/primitives/BlockedSection';
import { ErrorState, LoadingState } from '@components/primitives/States';
import { Icon } from '@components/Icon';
import { useMyTeams, useTeamMembers } from '@/data/hooks';
import { relativeTimeLabel } from '@/data/adapters';
import { font, fz, ls, sp, tt } from '@theme/tokens';

export default function TeamsTab() {
  const router = useRouter();
  const teams = useMyTeams();
  const [teamId, setTeamId] = useState<string | null>(null);

  useEffect(() => {
    if (teamId == null && teams.data && teams.data.length > 0) {
      setTeamId(teams.data[0]!.id);
    }
  }, [teams.data, teamId]);

  const members = useTeamMembers(teamId);

  return (
    <ScreenShell>
      <TTAppBar
        sub="LIVE TETHER"
        right={
          <View style={{ flexDirection: 'row', gap: sp.s2 }}>
            <IconBtn name="plus" />
            <IconBtn name="more" />
          </View>
        }
      />
      <ScrollView
        contentContainerStyle={styles.body}
        showsVerticalScrollIndicator={false}
      >
        {teams.loading && <LoadingState />}
        {teams.error && !teams.loading && (
          <ErrorState error={teams.error} onRetry={teams.refetch} />
        )}
        {!teams.loading && teams.data && teams.data.length === 0 && (
          <BlockedSection
            number={16}
            title="You're not in any teams yet"
            note="Create one or accept an invite to start sharing your live position."
          />
        )}

        {teams.data && teams.data.length > 0 && (
          <ChipRow
            value={teamId ?? teams.data[0]!.id}
            onChange={(id) => setTeamId(id)}
            items={teams.data.map((t) => ({ id: t.id, label: t.name }))}
            style={{ marginBottom: sp.s5 }}
          />
        )}

        {teamId && members.loading && <LoadingState />}
        {teamId && members.error && !members.loading && (
          <ErrorState error={members.error} onRetry={members.refetch} />
        )}
        {teamId && members.data && members.data.length === 0 && !members.loading && (
          <Text style={styles.empty}>No live positions in this team yet.</Text>
        )}
        {members.data?.map((m) => (
          <Card key={m.uid} tight style={{ marginTop: sp.s3 }}>
            <View style={styles.row}>
              <View style={[styles.avatar, { backgroundColor: m.color }]}>
                <Text style={styles.avatarText}>{m.initials}</Text>
              </View>
              <View style={{ flex: 1, minWidth: 0 }}>
                <View style={styles.nameRow}>
                  <Text style={styles.name} numberOfLines={1}>
                    {m.name}
                  </Text>
                  {m.lead && (
                    <View
                      style={[
                        styles.badge,
                        { backgroundColor: tt.emberDim, borderColor: 'rgba(255,106,44,0.45)' },
                      ]}
                    >
                      <Text style={[styles.badgeText, { color: tt.ember }]}>LEAD</Text>
                    </View>
                  )}
                  {m.alert && (
                    <View
                      style={[
                        styles.badge,
                        { backgroundColor: 'rgba(230,61,46,0.15)', borderColor: 'rgba(230,61,46,0.45)' },
                      ]}
                    >
                      <Text style={[styles.badgeText, { color: tt.red }]}>ALERT</Text>
                    </View>
                  )}
                </View>
                <Text style={styles.meta} numberOfLines={1}>
                  {m.locationLabel} · {Math.round(m.altitudeM)} M
                </Text>
                <Text style={styles.sub} numberOfLines={1}>
                  {relativeTimeLabel(m.lastSeen)}{' '}
                  · {m.batteryPct != null ? `${m.batteryPct}% batt` : 'battery —'}
                  {m.connectivity ? ` · ${m.connectivity}` : ''}
                </Text>
              </View>
              <Icon name="chevron-right" size={14} color={tt.text3} />
            </View>
          </Card>
        ))}

        {teamId && (
          <Pressable
            onPress={() => router.push('/plan-route')}
            style={({ pressed }) => [styles.startBtn, pressed && { opacity: 0.9 }]}
          >
            <Icon name="play" size={14} color="#1a0d04" strokeWidth={2.6} />
            <Text style={styles.startText}>START HIKE</Text>
          </Pressable>
        )}
      </ScrollView>
    </ScreenShell>
  );
}

const styles = StyleSheet.create({
  body: { paddingHorizontal: sp.screen, paddingBottom: sp.s11 },
  row: { flexDirection: 'row', alignItems: 'center', gap: sp.s5 },
  avatar: {
    width: 40,
    height: 40,
    borderRadius: 20,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: {
    fontFamily: font.uiHeavy,
    fontSize: 14,
    color: '#1a0d04',
    letterSpacing: ls.tight * 14,
  },
  nameRow: { flexDirection: 'row', alignItems: 'center', gap: 6 },
  name: { fontFamily: font.uiBold, fontSize: fz.rowTitle, color: tt.text, flexShrink: 1 },
  meta: {
    marginTop: 2,
    fontFamily: font.uiMed,
    fontSize: fz.body,
    color: tt.text2,
  },
  sub: {
    marginTop: 2,
    fontFamily: font.monoSemi,
    fontSize: fz.micro2,
    color: tt.text3,
    letterSpacing: ls.monoTight * fz.micro2,
  },
  badge: {
    paddingVertical: 1,
    paddingHorizontal: 6,
    borderRadius: 5,
    borderWidth: 1,
  },
  badgeText: {
    fontFamily: font.monoBold,
    fontSize: 8,
    letterSpacing: ls.monoWide * 8,
  },
  empty: {
    marginTop: sp.s7,
    textAlign: 'center',
    fontFamily: font.uiMed,
    fontSize: fz.body,
    color: tt.text3,
  },
  startBtn: {
    marginTop: sp.s7,
    height: 50,
    borderRadius: 14,
    backgroundColor: tt.ember,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: 10,
  },
  startText: {
    fontFamily: font.uiHeavy,
    fontSize: fz.body2,
    letterSpacing: ls.monoWide * fz.body2,
    color: '#1a0d04',
  },
});
