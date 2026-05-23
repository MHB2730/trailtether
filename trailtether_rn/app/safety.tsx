// Trailtether — Safety Center.
//
// Static rescue numbers (RESCUE_SERVICES_DRAKENSBERG) + the user's
// emergency_contacts rows + active safety plan + gear checklist, all
// real Supabase reads now that BLOCKERS #15, #16 are resolved.

import React from 'react';
import {
  Linking,
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
import { ErrorState, LoadingState } from '@components/primitives/States';
import { Icon } from '@components/Icon';
import { RESCUE_SERVICES_DRAKENSBERG } from '@/data/rescue_services';
import {
  useActiveSafetyPlan,
  useEmergencyContacts,
  useNearbyHazards,
} from '@/data/hooks';
import { relativeTimeLabel, shortDateLabel } from '@/data/adapters';
import { font, fz, ls, radius, shadow, sp, tt } from '@theme/tokens';

export default function SafetyScreen() {
  const router = useRouter();
  const contacts = useEmergencyContacts();
  const plan = useActiveSafetyPlan();
  const hazards = useNearbyHazards();

  const dial = (phone: string) => {
    void Linking.openURL(`tel:${phone.replace(/\s+/g, '')}`);
  };

  return (
    <ScreenShell>
      <TTAppBar
        big
        title="Safety Center"
        sub="PLAN · CONTACTS · GEAR"
        leftIcon="chevron-up"
        onPressLeft={() => router.back()}
        right={<IconBtn name="settings" onPress={() => router.push('/settings')} />}
      />
      <ScrollView
        contentContainerStyle={styles.body}
        showsVerticalScrollIndicator={false}
      >
        <Pressable
          onPress={() => router.push('/sos')}
          style={({ pressed }) => [styles.sosBtn, pressed && { opacity: 0.95 }]}
        >
          <View style={styles.sosCenter}>
            <Icon name="sos" size={26} color="#fff" strokeWidth={2.6} />
            <View style={{ marginLeft: sp.s5 }}>
              <Text style={styles.sosTitle}>SOS BEACON</Text>
              <Text style={styles.sosSub}>Tap to broadcast live position</Text>
            </View>
          </View>
        </Pressable>

        <Text style={styles.sectionTitle}>RESCUE · DRAKENSBERG</Text>
        {RESCUE_SERVICES_DRAKENSBERG.map((c) => (
          <Card key={c.id} tight onPress={() => dial(c.phone)} style={{ marginTop: sp.s3 }}>
            <View style={styles.row}>
              <View style={styles.iconTile}>
                <Icon name="phone" size={14} color={tt.red} />
              </View>
              <View style={{ flex: 1 }}>
                <Text style={styles.title}>{c.name}</Text>
                <Text style={styles.sub}>{c.sub}</Text>
              </View>
              <Text style={styles.phone}>{c.phone}</Text>
            </View>
          </Card>
        ))}

        <Text style={styles.sectionTitle}>PERSONAL CONTACTS</Text>
        {contacts.loading && <LoadingState />}
        {contacts.error && !contacts.loading && (
          <ErrorState error={contacts.error} onRetry={contacts.refetch} />
        )}
        {contacts.data && contacts.data.length === 0 && !contacts.loading && (
          <Text style={styles.empty}>No personal contacts. Add one from Edit Profile.</Text>
        )}
        {contacts.data?.map((c) => (
          <Card key={c.id} tight onPress={() => dial(c.phone)} style={{ marginTop: sp.s3 }}>
            <View style={styles.row}>
              <View style={styles.iconTile}>
                <Icon name="phone" size={14} color={tt.ember} />
              </View>
              <View style={{ flex: 1 }}>
                <Text style={styles.title}>{c.name}</Text>
                {c.sub.length > 0 && <Text style={styles.sub}>{c.sub}</Text>}
              </View>
              <Text style={styles.phone}>{c.phone}</Text>
            </View>
          </Card>
        ))}

        <Text style={styles.sectionTitle}>ACTIVE PLAN</Text>
        {plan.loading && <LoadingState />}
        {plan.error && !plan.loading && (
          <ErrorState error={plan.error} onRetry={plan.refetch} />
        )}
        {plan.data ? (
          <Card style={{ marginTop: sp.s3 }}>
            <View style={styles.row}>
              <View style={[styles.iconTile, { backgroundColor: tt.emberDim, borderColor: 'rgba(255,106,44,0.45)' }]}>
                <Icon name="route" size={14} color={tt.ember} />
              </View>
              <View style={{ flex: 1 }}>
                <Text style={styles.title}>{plan.data.trailName}</Text>
                <Text style={styles.sub}>
                  Expected return {shortDateLabel(plan.data.expectedReturn)} ·{' '}
                  {plan.data.watcherCount} watcher
                  {plan.data.watcherCount === 1 ? '' : 's'}
                </Text>
                {plan.data.lastPing && (
                  <Text style={[styles.sub, { color: tt.green }]}>
                    Last ping {relativeTimeLabel(plan.data.lastPing)}
                  </Text>
                )}
              </View>
            </View>
          </Card>
        ) : (
          !plan.loading &&
          !plan.error && (
            <Text style={styles.empty}>No active safety plan. Arm a tether from Plan Route.</Text>
          )
        )}

        {plan.data && plan.data.gear.length > 0 && (
          <>
            <Text style={styles.sectionTitle}>GEAR CHECKLIST</Text>
            {plan.data.gear.map((g) => (
              <Card key={g.id} tight style={{ marginTop: sp.s3 }}>
                <View style={styles.row}>
                  <View style={[styles.iconTile, g.done && { backgroundColor: 'rgba(76,195,138,0.15)', borderColor: 'rgba(76,195,138,0.45)' }]}>
                    <Icon
                      name={g.done ? 'check' : 'plus'}
                      size={14}
                      color={g.done ? tt.green : tt.text3}
                    />
                  </View>
                  <View style={{ flex: 1 }}>
                    <Text style={styles.title}>{g.label}</Text>
                    {g.sub && <Text style={styles.sub}>{g.sub}</Text>}
                  </View>
                </View>
              </Card>
            ))}
          </>
        )}

        <Text style={styles.sectionTitle}>RECENT HAZARDS</Text>
        {hazards.loading && <LoadingState />}
        {hazards.error && !hazards.loading && (
          <ErrorState error={hazards.error} onRetry={hazards.refetch} />
        )}
        {hazards.data?.slice(0, 5).map((h) => (
          <Card key={h.id} tight style={{ marginTop: sp.s3 }}>
            <View style={styles.row}>
              <Icon name={h.iconName} size={14} color={tt.amber} />
              <View style={{ flex: 1 }}>
                <Text style={styles.title} numberOfLines={1}>
                  {h.title}
                </Text>
                <Text style={styles.sub} numberOfLines={2}>
                  {h.sub}
                </Text>
              </View>
              <Text style={styles.phone}>{h.timeLabel}</Text>
            </View>
          </Card>
        ))}
      </ScrollView>
    </ScreenShell>
  );
}

const styles = StyleSheet.create({
  body: { paddingHorizontal: sp.screen, paddingBottom: sp.s11 },
  sosBtn: {
    paddingVertical: sp.s8,
    paddingHorizontal: sp.s7,
    borderRadius: radius.lg,
    backgroundColor: tt.red,
    borderWidth: 1,
    borderColor: 'rgba(230,61,46,0.65)',
    ...shadow.ember,
    shadowColor: tt.red,
  },
  sosCenter: { flexDirection: 'row', alignItems: 'center', justifyContent: 'center' },
  sosTitle: {
    fontFamily: font.uiHeavy,
    fontSize: 16,
    color: '#fff',
    letterSpacing: ls.monoWide * 16,
  },
  sosSub: {
    marginTop: 2,
    fontFamily: font.uiMed,
    fontSize: 12,
    color: 'rgba(255,255,255,0.85)',
  },
  sectionTitle: {
    marginTop: sp.s9,
    marginBottom: sp.s3,
    fontFamily: font.uiBold,
    fontSize: 11,
    color: tt.text2,
    letterSpacing: ls.monoWide * 11,
    textTransform: 'uppercase',
  },
  row: { flexDirection: 'row', alignItems: 'center', gap: sp.s5 },
  iconTile: {
    width: 34,
    height: 34,
    borderRadius: 9,
    backgroundColor: 'rgba(230,61,46,0.13)',
    borderWidth: 1,
    borderColor: 'rgba(230,61,46,0.32)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  title: { fontFamily: font.uiBold, fontSize: fz.rowTitle, color: tt.text },
  sub: { marginTop: 2, fontFamily: font.uiMed, fontSize: fz.body, color: tt.text2 },
  phone: {
    fontFamily: font.monoBold,
    fontSize: fz.caption,
    color: tt.ember,
    letterSpacing: ls.monoTight * fz.caption,
  },
  empty: {
    marginTop: sp.s4,
    fontFamily: font.uiMed,
    fontSize: fz.body,
    color: tt.text3,
  },
});
