// Trailtether — Plan a Route.
//
// Lets the user build a route: name, date, start time, target trail,
// and a watcher team. Saves a header row into `route_plans` plus a
// stub start/end waypoint pair into `route_waypoints` (resolved
// BLOCKERS #18). The richer draggable waypoint UI will replace the
// stub pair in a follow-up; for now the schema is in place and a
// SAVE produces a real, durable record.

import React, { useMemo, useState } from 'react';
import {
  KeyboardAvoidingView,
  Platform,
  Pressable,
  ScrollView,
  StyleSheet,
  Text,
  View,
} from 'react-native';
import { useRouter } from 'expo-router';
import { ScreenShell } from '@components/primitives/ScreenShell';
import { TTAppBar, IconBtn } from '@components/primitives/TTAppBar';
import { FormField } from '@components/design/FormField';
import { BlockedSection } from '@components/primitives/BlockedSection';
import { ErrorState, LoadingState } from '@components/primitives/States';
import { Icon } from '@components/Icon';
import { useMyTeams, useTrailsCatalog, parseBlocked } from '@/data/hooks';
import { useAuth } from '@/store/auth';
import { supabase } from '@/data/supabase';
import { shortDateLabel } from '@/data/adapters';
import { font, fz, ls, radius, shadow, sp, tt } from '@theme/tokens';

export default function PlanRouteScreen() {
  const router = useRouter();
  const uid = useAuth((s) => s.user?.id);
  const trails = useTrailsCatalog();
  const teams = useMyTeams();

  const [name, setName] = useState('');
  const [trailId, setTrailId] = useState<string | null>(null);
  const [teamId, setTeamId] = useState<string | null>(null);
  const [meetingPoint, setMeetingPoint] = useState('');
  const [notes, setNotes] = useState('');
  const [date] = useState(new Date(Date.now() + 24 * 3600 * 1000));
  const [saving, setSaving] = useState(false);
  const [error, setError] = useState<string | null>(null);
  const [showTrailPicker, setShowTrailPicker] = useState(false);
  const [showTeamPicker, setShowTeamPicker] = useState(false);

  const selectedTrail = useMemo(
    () => trails.data?.find((t) => t.id === trailId) ?? null,
    [trails.data, trailId],
  );
  const selectedTeam = useMemo(
    () => teams.data?.find((t) => t.id === teamId) ?? null,
    [teams.data, teamId],
  );
  const trailBlocked = parseBlocked(trails.error);

  const save = async () => {
    if (!uid || !trailId || !selectedTrail) return;
    setSaving(true);
    setError(null);
    try {
      // 1) route_plans header row.
      const { data: planRow, error: pErr } = await supabase
        .from('route_plans')
        .insert({
          user_id: uid,
          name: (name.trim() || selectedTrail.name),
          trail_id: trailId,
          hike_date: date.toISOString(),
          watcher_team_id: teamId,
          total_km: selectedTrail.distanceKm,
          ascent_m: selectedTrail.ascentM,
          duration_minutes: Math.round(selectedTrail.distanceKm * 18), // rough 18 min/km
          notes: notes.trim() || null,
          is_draft: false,
        })
        .select('id')
        .single();
      if (pErr) throw pErr;

      // 2) stub waypoints — start + end. Replace with the draggable
      //    list once the UI lands.
      const planId = (planRow as { id: string }).id;
      const { error: wErr } = await supabase.from('route_waypoints').insert([
        {
          route_id: planId,
          idx: 0,
          num: 'A',
          type: 'start',
          name: meetingPoint.trim() || 'Trailhead',
          km: 0,
        },
        {
          route_id: planId,
          idx: 1,
          num: 'B',
          type: 'end',
          name: 'Summit / turn-around',
          km: selectedTrail.distanceKm,
        },
      ]);
      if (wErr) throw wErr;

      // 3) mirror into hike_plans so the Home upcoming-hike card sees it
      //    (the new view v_upcoming_hikes_for_user is the consumer).
      await supabase.from('hike_plans').insert({
        trail_id: trailId,
        trail_name: selectedTrail.name,
        team_id: teamId,
        meeting_point: meetingPoint.trim() || null,
        notes: notes.trim() || null,
        hike_date: date.toISOString(),
        created_by: uid,
        status: 'planned',
      });

      router.back();
    } catch (err) {
      setError(err instanceof Error ? err.message : String(err));
    } finally {
      setSaving(false);
    }
  };

  return (
    <ScreenShell scroll={false}>
      <TTAppBar
        big
        title="Plan a Route"
        sub="ROUTE · WATCHER · NOTES"
        leftIcon="chevron-up"
        onPressLeft={() => router.back()}
        right={<IconBtn name="check" color={tt.ember} onPress={() => void save()} />}
      />
      <KeyboardAvoidingView
        behavior={Platform.OS === 'ios' ? 'padding' : undefined}
        style={{ flex: 1 }}
      >
        <ScrollView
          contentContainerStyle={styles.body}
          keyboardShouldPersistTaps="handled"
          showsVerticalScrollIndicator={false}
        >
          <FormField
            label="Hike name"
            icon="route"
            value={name}
            onChangeText={setName}
            placeholder="Cathedral Peak loop"
          />
          <FormField
            label="Trail"
            icon="mountain"
            value={selectedTrail?.name ?? ''}
            onChangeText={() => {}}
            placeholder="Choose from catalog"
            onPress={() => setShowTrailPicker((v) => !v)}
            hint={
              selectedTrail
                ? `${selectedTrail.region.toUpperCase()} · ${selectedTrail.distanceKm.toFixed(1)} KM`
                : undefined
            }
          />
          {showTrailPicker && (
            <View style={styles.picker}>
              {trails.loading && <LoadingState />}
              {trailBlocked && (
                <BlockedSection
                  number={trailBlocked.n}
                  title="Trails not bundled yet"
                  note={trailBlocked.reason}
                />
              )}
              {trails.data?.slice(0, 12).map((t) => (
                <Pressable
                  key={t.id}
                  onPress={() => {
                    setTrailId(t.id);
                    setShowTrailPicker(false);
                  }}
                  style={({ pressed }) => [styles.pickerRow, pressed && styles.pickerRowPressed]}
                >
                  <Text style={styles.pickerName} numberOfLines={1}>
                    {t.name}
                  </Text>
                  <Text style={styles.pickerMeta} numberOfLines={1}>
                    {t.region} · {t.distanceKm.toFixed(1)} km · ↑{t.ascentM} m
                  </Text>
                </Pressable>
              ))}
            </View>
          )}
          <FormField
            label="Date"
            icon="clock"
            value={shortDateLabel(date)}
            onChangeText={() => {}}
            placeholder="Tomorrow"
            editable={false}
            hint="Time picker pending — saves at the chosen date midday local."
          />
          <FormField
            label="Tether watcher"
            icon="people"
            value={selectedTeam?.name ?? ''}
            onChangeText={() => {}}
            placeholder="Pick a team"
            onPress={() => setShowTeamPicker((v) => !v)}
            hint={teams.loading ? 'Loading teams…' : undefined}
          />
          {showTeamPicker && (
            <View style={styles.picker}>
              {teams.loading && <LoadingState />}
              {teams.error && !teams.loading && (
                <ErrorState error={teams.error} onRetry={teams.refetch} />
              )}
              {teams.data?.length === 0 && !teams.loading && (
                <Text style={styles.pickerEmpty}>You're not in any teams yet.</Text>
              )}
              {teams.data?.map((t) => (
                <Pressable
                  key={t.id}
                  onPress={() => {
                    setTeamId(t.id);
                    setShowTeamPicker(false);
                  }}
                  style={({ pressed }) => [styles.pickerRow, pressed && styles.pickerRowPressed]}
                >
                  <Text style={styles.pickerName} numberOfLines={1}>
                    {t.name}
                  </Text>
                </Pressable>
              ))}
            </View>
          )}
          <FormField
            label="Meeting point"
            icon="pin"
            value={meetingPoint}
            onChangeText={setMeetingPoint}
            placeholder="Trailhead parking · 06:30"
          />
          <FormField
            label="Notes"
            icon="alert"
            value={notes}
            onChangeText={setNotes}
            placeholder="Bring rope · weather marginal after 14:00"
            multiline
            numberOfLines={3}
          />

          {error && <ErrorState error={error} />}

          <Pressable
            onPress={() => void save()}
            disabled={!trailId || saving}
            style={({ pressed }) => [
              styles.cta,
              (!trailId || saving) && { opacity: 0.5 },
              pressed && { opacity: 0.9 },
            ]}
          >
            <Text style={styles.ctaText}>{saving ? 'SAVING…' : 'SAVE PLAN'}</Text>
            <Icon name="check" size={16} color="#1a0d04" strokeWidth={2.6} />
          </Pressable>
        </ScrollView>
      </KeyboardAvoidingView>
    </ScreenShell>
  );
}

const styles = StyleSheet.create({
  body: { padding: sp.screen, paddingBottom: sp.s11 },
  picker: {
    marginTop: -sp.s4,
    marginBottom: sp.s6,
    backgroundColor: tt.surf,
    borderRadius: radius.md,
    borderWidth: 1,
    borderColor: tt.line2,
    overflow: 'hidden',
  },
  pickerRow: {
    padding: sp.s5,
    borderBottomWidth: 1,
    borderBottomColor: tt.line,
  },
  pickerRowPressed: { backgroundColor: tt.surf2 },
  pickerName: { fontFamily: font.uiBold, fontSize: fz.body2, color: tt.text },
  pickerMeta: {
    marginTop: 2,
    fontFamily: font.monoSemi,
    fontSize: fz.micro2,
    color: tt.text3,
    letterSpacing: ls.monoTight * fz.micro2,
  },
  pickerEmpty: {
    padding: sp.s5,
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
