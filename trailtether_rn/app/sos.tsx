// Trailtether — SOS Active.
//
// The activation flow needs a write path into `incidents` + a server
// pipeline that paginates responders + assigns beacons (BLOCKERS.md
// #17). Until that lands, this screen reads the user's most-recent
// open incident (if any) and renders it as the "active SOS" panel;
// otherwise it surfaces a banner and a big armed-button that explains
// the gap.

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
import { ErrorState, LoadingState } from '@components/primitives/States';
import { Icon } from '@components/Icon';
import { supabase } from '@/data/supabase';
import type { IncidentRow } from '@/data/schema';
import { relativeTimeLabel, timeOfDayLabel } from '@/data/adapters';
import { font, fz, ls, radius, shadow, sp, tt } from '@theme/tokens';
import { useAuth } from '@/store/auth';
import { useIncidentTimeline } from '@/data/hooks';

export default function SOSScreen() {
  const router = useRouter();
  const uid = useAuth((s) => s.user?.id);
  const [active, setActive] = useState<IncidentRow | null>(null);
  const [loading, setLoading] = useState(true);
  const [error, setError] = useState<string | null>(null);

  useEffect(() => {
    let cancelled = false;
    (async () => {
      if (!uid) {
        setLoading(false);
        return;
      }
      try {
        const { data, error: err } = await supabase
          .from('incidents')
          .select('*')
          .eq('created_by', uid)
          .eq('is_emergency', true)
          .order('reported_at', { ascending: false })
          .limit(1)
          .maybeSingle();
        if (err) throw err;
        if (!cancelled) setActive((data as IncidentRow | null) ?? null);
      } catch (err) {
        if (!cancelled) setError(err instanceof Error ? err.message : String(err));
      } finally {
        if (!cancelled) setLoading(false);
      }
    })();
    return () => {
      cancelled = true;
    };
  }, [uid]);

  const startedAt = active?.reported_at ? new Date(active.reported_at) : null;
  const timeline = useIncidentTimeline(active?.id ?? null);

  return (
    <ScreenShell>
      <TTAppBar
        big
        title={active ? 'SOS Active' : 'SOS Armed'}
        sub={active ? 'LIVE BEACON' : 'TAP TO BROADCAST'}
        leftIcon="chevron-up"
        onPressLeft={() => router.back()}
        right={<IconBtn name="more" />}
      />
      <ScrollView
        contentContainerStyle={styles.body}
        showsVerticalScrollIndicator={false}
      >
        {loading && <LoadingState />}
        {error && !loading && <ErrorState error={error} />}

        {active && startedAt && (
          <Card style={styles.activeCard}>
            <View style={styles.activeRow}>
              <View style={styles.pulse}>
                <Icon name="sos" size={22} color="#fff" strokeWidth={2.6} />
              </View>
              <View style={{ flex: 1, minWidth: 0 }}>
                <Text style={styles.activeTitle}>
                  {active.title?.trim() || 'EMERGENCY BEACON'}
                </Text>
                <Text style={styles.activeSub}>
                  Broadcasting from {active.lat.toFixed(4)}, {active.lon.toFixed(4)}
                </Text>
                <Text style={styles.activeMeta}>
                  Started {relativeTimeLabel(startedAt)} · {timeOfDayLabel(startedAt)}
                </Text>
              </View>
            </View>
          </Card>
        )}

        {!active && !loading && (
          <Pressable
            onPress={() => {}}
            style={({ pressed }) => [styles.bigArm, pressed && { opacity: 0.95 }]}
          >
            <Icon name="sos" size={48} color="#fff" strokeWidth={2.6} />
            <Text style={styles.bigArmText}>HOLD TO ACTIVATE</Text>
            <Text style={styles.bigArmSub}>3-second confirm prevents accidental triggers.</Text>
          </Pressable>
        )}

        {active && (active.responder_status || active.beacon_id) && (
          <Card style={{ marginTop: sp.s6 }}>
            <Text style={styles.sectionEyebrow}>RESPONDER</Text>
            {active.beacon_id && (
              <Text style={styles.beacon}>{active.beacon_id}</Text>
            )}
            {active.responder_status && (
              <View style={styles.responderRow}>
                <View style={[styles.statusDot, { backgroundColor: responderColor(active.responder_status) }]} />
                <Text style={styles.responderStatus}>
                  {active.responder_status.toUpperCase()}
                </Text>
                {active.responder_eta_minutes != null && (
                  <Text style={styles.responderEta}>
                    ETA {active.responder_eta_minutes} MIN
                  </Text>
                )}
                {active.responder_distance_metres != null && (
                  <Text style={styles.responderEta}>
                    {(active.responder_distance_metres / 1000).toFixed(1)} KM
                  </Text>
                )}
              </View>
            )}
            {active.accuracy_m != null && (
              <Text style={styles.activeMeta}>
                Position accurate to ±{Math.round(active.accuracy_m)} m
              </Text>
            )}
          </Card>
        )}

        {active && (
          <Card style={{ marginTop: sp.s4 }}>
            <Text style={styles.sectionEyebrow}>DISPATCH TIMELINE</Text>
            {timeline.loading && <LoadingState />}
            {timeline.error && !timeline.loading && (
              <ErrorState error={timeline.error} onRetry={timeline.refetch} />
            )}
            {!timeline.loading && !timeline.error && timeline.data && timeline.data.length === 0 && (
              <Text style={styles.timelineEmpty}>No dispatch events recorded yet.</Text>
            )}
            {timeline.data?.map((ev, i) => (
              <View key={i} style={styles.tlRow}>
                <View
                  style={[
                    styles.tlDot,
                    { backgroundColor: timelineColor(ev.status) },
                  ]}
                />
                <View style={{ flex: 1 }}>
                  <Text style={styles.tlLabel}>{ev.label}</Text>
                  <Text style={styles.tlTime}>{ev.timeLabel}</Text>
                </View>
              </View>
            ))}
          </Card>
        )}
      </ScrollView>
    </ScreenShell>
  );
}

function responderColor(status: string): string {
  switch (status) {
    case 'on scene':
      return tt.green;
    case 'cleared':
      return tt.blue;
    case 'en route':
    default:
      return tt.amber;
  }
}

function timelineColor(status: 'done' | 'active' | 'pending') {
  switch (status) {
    case 'done':    return tt.green;
    case 'active':  return tt.ember;
    case 'pending': return tt.text3;
  }
}

const styles = StyleSheet.create({
  body: { paddingHorizontal: sp.screen, paddingBottom: sp.s11 },
  activeCard: {
    backgroundColor: 'rgba(230,61,46,0.08)',
    borderColor: 'rgba(230,61,46,0.45)',
    ...shadow.ember,
    shadowColor: tt.red,
  },
  activeRow: { flexDirection: 'row', alignItems: 'center', gap: sp.s5 },
  pulse: {
    width: 56,
    height: 56,
    borderRadius: 28,
    backgroundColor: tt.red,
    alignItems: 'center',
    justifyContent: 'center',
  },
  activeTitle: {
    fontFamily: font.uiHeavy,
    fontSize: fz.cardTitle,
    color: tt.text,
    letterSpacing: ls.tight * fz.cardTitle,
  },
  activeSub: {
    marginTop: 4,
    fontFamily: font.monoSemi,
    fontSize: fz.body,
    color: tt.text2,
    letterSpacing: ls.monoTight * fz.body,
  },
  activeMeta: {
    marginTop: 4,
    fontFamily: font.monoBold,
    fontSize: 10,
    color: tt.text3,
    letterSpacing: ls.monoWide * 10,
  },
  bigArm: {
    marginTop: sp.s5,
    paddingVertical: sp.s11,
    paddingHorizontal: sp.s7,
    borderRadius: radius.xl,
    backgroundColor: tt.red,
    alignItems: 'center',
    ...shadow.ember,
    shadowColor: tt.red,
  },
  bigArmText: {
    marginTop: sp.s5,
    fontFamily: font.uiHeavy,
    fontSize: 18,
    color: '#fff',
    letterSpacing: ls.monoWide * 18,
  },
  bigArmSub: {
    marginTop: 6,
    fontFamily: font.uiMed,
    fontSize: fz.body,
    color: 'rgba(255,255,255,0.85)',
    textAlign: 'center',
  },
  sectionEyebrow: {
    fontFamily: font.uiBold,
    fontSize: 10.5,
    color: tt.text3,
    letterSpacing: ls.monoWide * 10.5,
    textTransform: 'uppercase',
    marginBottom: sp.s4,
  },
  beacon: {
    fontFamily: font.monoBold,
    fontSize: fz.body2,
    color: tt.ember,
    letterSpacing: ls.monoWide * fz.body2,
    marginBottom: sp.s3,
  },
  responderRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: sp.s3,
    marginBottom: sp.s3,
  },
  statusDot: { width: 9, height: 9, borderRadius: 4.5 },
  responderStatus: {
    fontFamily: font.monoBold,
    fontSize: fz.body,
    color: tt.text,
    letterSpacing: ls.monoMed * fz.body,
  },
  responderEta: {
    fontFamily: font.monoSemi,
    fontSize: fz.body,
    color: tt.text2,
    letterSpacing: ls.monoTight * fz.body,
  },
  tlRow: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: sp.s4,
    paddingVertical: sp.s3,
    borderTopWidth: 1,
    borderTopColor: tt.line,
  },
  tlDot: { width: 10, height: 10, borderRadius: 5 },
  tlLabel: { fontFamily: font.uiBold, fontSize: fz.body2, color: tt.text },
  tlTime: {
    marginTop: 2,
    fontFamily: font.monoBold,
    fontSize: 10,
    color: tt.text3,
    letterSpacing: ls.monoTight * 10,
  },
  timelineEmpty: {
    fontFamily: font.uiMed,
    fontSize: fz.body,
    color: tt.text3,
    textAlign: 'center',
    paddingVertical: sp.s5,
  },
});
