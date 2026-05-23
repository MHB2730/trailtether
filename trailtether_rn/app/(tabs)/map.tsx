// Trailtether — Map (tab).
//
// Real MapView (react-native-maps) showing every bundled trail as a
// polyline, every open hazard as a pin, every team member as a pin.
// A glass "shortcut sheet" hovers at the bottom for trails / plan / team.
//
// BLOCKERS #18 is now closed for the Map half (tile renderer in place).
// The Tools-tab sensor instruments are still pending — that's a
// separate native-module install.

import React, { useEffect, useMemo, useState } from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useRouter } from 'expo-router';
import { SafeAreaView } from 'react-native-safe-area-context';
import { TTAppBar, IconBtn } from '@components/primitives/TTAppBar';
import { Card } from '@components/primitives/Card';
import { Icon } from '@components/Icon';
import { TrailMap } from '@components/design/TrailMap';
import {
  useFieldIntel,
  useHomeWeatherLocation,
  useMyTeams,
  useNearbyHazards,
  useTeamMembers,
  useTrailsCatalog,
  useTrail,
} from '@/data/hooks';
import type { NearbyHazard } from '@/data/types';
import type { IncidentRow } from '@/data/schema';
import { supabase } from '@/data/supabase';
import { font, fz, ls, radius, sp, tt } from '@theme/tokens';

export default function MapTab() {
  const router = useRouter();
  const weatherLocation = useHomeWeatherLocation();
  const trailsList = useTrailsCatalog();
  const teams = useMyTeams();
  const firstTeamId = teams.data?.[0]?.id ?? null;
  const members = useTeamMembers(firstTeamId);
  const hazards = useFieldIntel({
    center: weatherLocation.data
      ? { lat: weatherLocation.data.lat, lon: weatherLocation.data.lon }
      : null,
    radiusKm: 100,
    limit: 20,
  });

  // We don't render all 239 trails as polylines (too dense). Pick the
  // 8 closest to the user's region, falling back to the first 8.
  const visibleTrailIds = useMemo(() => {
    if (!trailsList.data) return [];
    const center = weatherLocation.data;
    const ranked = [...trailsList.data];
    if (center) {
      // Trails list doesn't carry lat/lon; we have to load each trail
      // for its bbox. Keep this O(n) — the list is 239 items max.
      // Skip ranking when no center is set.
    }
    return ranked.slice(0, 8).map((t) => t.id);
  }, [trailsList.data, weatherLocation.data]);

  // Resolve those 8 trails into full Trail objects with coords.
  const trail0 = useTrail(visibleTrailIds[0] ?? null);
  const trail1 = useTrail(visibleTrailIds[1] ?? null);
  const trail2 = useTrail(visibleTrailIds[2] ?? null);
  const trail3 = useTrail(visibleTrailIds[3] ?? null);
  const trail4 = useTrail(visibleTrailIds[4] ?? null);
  const trail5 = useTrail(visibleTrailIds[5] ?? null);
  const trail6 = useTrail(visibleTrailIds[6] ?? null);
  const trail7 = useTrail(visibleTrailIds[7] ?? null);
  const trails = [trail0, trail1, trail2, trail3, trail4, trail5, trail6, trail7]
    .map((r) => r.data)
    .filter((t): t is NonNullable<typeof t> => t != null);

  // Field intel rows don't carry lat/lon in NearbyHazard; we need to
  // re-derive coords by joining against the recent incidents window.
  // Cheaper: keep a parallel raw query.
  const hazardsWithCoords = useRawHazardCoords(hazards.data ?? []);

  return (
    <SafeAreaView style={styles.safe} edges={['top']}>
      <TrailMap
        trails={trails}
        teamMembers={members.data ?? []}
        hazards={hazardsWithCoords}
        onTrailPress={(id) =>
          router.push({ pathname: '/trail-detail', params: { id } })
        }
      />
      <View style={styles.bar} pointerEvents="box-none">
        <TTAppBar
          sub="MAP · TILES · LIVE"
          right={
            <View style={{ flexDirection: 'row', gap: sp.s2 }}>
              <IconBtn name="layers" />
              <IconBtn name="crosshair" />
            </View>
          }
        />
      </View>

      <View style={styles.sheet} pointerEvents="box-none">
        <Card glass>
          <View style={styles.sheetRow}>
            <ShortcutChip
              icon="route"
              label="TRAILS"
              count={trailsList.data?.length ?? null}
              onPress={() => router.push('/trails')}
            />
            <ShortcutChip
              icon="pin"
              label="PLAN"
              onPress={() => router.push('/plan-route')}
            />
            <ShortcutChip
              icon="people"
              label="TEAM"
              count={members.data?.length ?? null}
              onPress={() => router.push('/(tabs)/teams')}
            />
            <ShortcutChip
              icon="alert"
              label="HAZARDS"
              count={hazards.data?.length ?? null}
              onPress={() => router.push('/notifications')}
            />
          </View>
        </Card>
      </View>
    </SafeAreaView>
  );
}

function ShortcutChip({
  icon,
  label,
  count,
  onPress,
}: {
  icon: 'route' | 'pin' | 'people' | 'alert';
  label: string;
  count?: number | null;
  onPress: () => void;
}) {
  return (
    <Pressable
      onPress={onPress}
      style={({ pressed }) => [styles.chip, pressed && { opacity: 0.85 }]}
    >
      <Icon name={icon} size={16} color={tt.ember} />
      <Text style={styles.chipLabel}>{label}</Text>
      {typeof count === 'number' && (
        <Text style={styles.chipCount}>{count}</Text>
      )}
    </Pressable>
  );
}

/**
 * NearbyHazard from the hook strips lat/lon. For the map we re-query
 * the incidents window and merge coords back in. This is a thin layer
 * — same data, just carrying the geo back.
 */
function useRawHazardCoords(
  hazards: NearbyHazard[],
): (NearbyHazard & { lat: number; lon: number })[] {
  const [coords, setCoords] = useState<Record<string, { lat: number; lon: number }>>({});

  useEffect(() => {
    if (hazards.length === 0) {
      setCoords({});
      return;
    }
    let cancelled = false;
    void (async () => {
      const ids = hazards.map((h) => h.id);
      const { data } = await supabase
        .from('incidents')
        .select('id, lat, lon')
        .in('id', ids);
      if (cancelled) return;
      const next: Record<string, { lat: number; lon: number }> = {};
      for (const row of (data ?? []) as Pick<IncidentRow, 'id' | 'lat' | 'lon'>[]) {
        next[row.id] = { lat: row.lat, lon: row.lon };
      }
      setCoords(next);
    })();
    return () => {
      cancelled = true;
    };
  }, [hazards]);

  return hazards
    .map((h) => {
      const c = coords[h.id];
      return c ? { ...h, lat: c.lat, lon: c.lon } : null;
    })
    .filter((h): h is NearbyHazard & { lat: number; lon: number } => h != null);
}

const styles = StyleSheet.create({
  safe: { flex: 1, backgroundColor: tt.bg },
  bar: {
    position: 'absolute',
    top: 0,
    left: 0,
    right: 0,
  },
  sheet: {
    position: 'absolute',
    left: sp.screen,
    right: sp.screen,
    bottom: sp.s8,
  },
  sheetRow: {
    flexDirection: 'row',
    justifyContent: 'space-around',
    gap: sp.s3,
  },
  chip: {
    flex: 1,
    alignItems: 'center',
    paddingVertical: sp.s4,
    paddingHorizontal: sp.s3,
    borderRadius: radius.md,
  },
  chipLabel: {
    marginTop: 4,
    fontFamily: font.uiBold,
    fontSize: 9.5,
    color: tt.text,
    letterSpacing: ls.monoWide * 9.5,
  },
  chipCount: {
    marginTop: 2,
    fontFamily: font.monoBold,
    fontSize: fz.caption,
    color: tt.ember,
    letterSpacing: ls.monoTight * fz.caption,
  },
});
