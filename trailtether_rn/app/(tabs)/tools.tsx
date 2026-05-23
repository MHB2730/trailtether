// Trailtether — Tools (tab).
//
// Grid of one-tap field tools. Each is its own route. Until the
// underlying instruments land (compass/altitude/sun need native
// modules that aren't in the bundle yet, BLOCKERS.md #18), each card
// navigates to a stub route that lives inside the screen.

import React from 'react';
import { Pressable, ScrollView, StyleSheet, Text, View } from 'react-native';
import { useRouter } from 'expo-router';
import { ScreenShell } from '@components/primitives/ScreenShell';
import { TTAppBar, IconBtn } from '@components/primitives/TTAppBar';
import { BlockedSection } from '@components/primitives/BlockedSection';
import { Icon, type IconName } from '@components/Icon';
import { font, fz, ls, radius, sp, tt } from '@theme/tokens';

interface ToolSpec {
  id: string;
  label: string;
  sub: string;
  iconName: IconName;
  route: string;
  ember?: boolean;
}

const TOOLS: ToolSpec[] = [
  { id: 'sos', label: 'SOS', sub: 'Live beacon · one tap', iconName: 'sos', route: '/sos', ember: true },
  { id: 'safety', label: 'Safety Center', sub: 'Plan · contacts · gear', iconName: 'shield', route: '/safety' },
  { id: 'plan', label: 'Plan a route', sub: 'Waypoints + watcher', iconName: 'route', route: '/plan-route' },
  { id: 'trails', label: 'Trails', sub: 'Browse + search routes', iconName: 'mountain', route: '/trails' },
  { id: 'forecast', label: 'Forecast', sub: '7-day · hike score', iconName: 'wind', route: '/forecast' },
  { id: 'compass', label: 'Compass', sub: 'Bearing + heading', iconName: 'compass', route: '/(tabs)/map' },
  { id: 'history', label: 'Hike history', sub: 'GPX recordings', iconName: 'history', route: '/history' },
  { id: 'notifications', label: 'Notifications', sub: 'Alerts · hazards', iconName: 'bell', route: '/notifications' },
];

export default function ToolsTab() {
  const router = useRouter();
  return (
    <ScreenShell>
      <TTAppBar
        sub="FIELD INSTRUMENTS"
        right={<IconBtn name="search" onPress={() => router.push('/search')} />}
      />
      <ScrollView
        contentContainerStyle={styles.body}
        showsVerticalScrollIndicator={false}
      >
        <BlockedSection
          number={18}
          title="Native instruments pending"
          note="Compass / level / altimeter need expo-sensors + barometer modules — installing those alongside the map renderer."
        />
        <View style={styles.grid}>
          {TOOLS.map((t) => (
            <Pressable
              key={t.id}
              onPress={() => router.push(t.route as never)}
              style={({ pressed }) => [
                styles.cell,
                t.ember && styles.cellEmber,
                pressed && { opacity: 0.85 },
              ]}
            >
              <View
                style={[
                  styles.iconTile,
                  t.ember && { backgroundColor: 'rgba(230,61,46,0.18)', borderColor: 'rgba(230,61,46,0.45)' },
                ]}
              >
                <Icon name={t.iconName} size={18} color={t.ember ? tt.red : tt.ember} />
              </View>
              <Text style={styles.label}>{t.label}</Text>
              <Text style={styles.sub}>{t.sub}</Text>
            </Pressable>
          ))}
        </View>
      </ScrollView>
    </ScreenShell>
  );
}

const styles = StyleSheet.create({
  body: { paddingHorizontal: sp.screen, paddingBottom: sp.s11 },
  grid: {
    marginTop: sp.s6,
    flexDirection: 'row',
    flexWrap: 'wrap',
    gap: sp.s3,
  },
  cell: {
    width: '47.5%',
    padding: sp.s7,
    backgroundColor: tt.surf,
    borderRadius: radius.lg,
    borderWidth: 1,
    borderColor: tt.line,
  },
  cellEmber: {
    borderColor: 'rgba(230,61,46,0.45)',
    backgroundColor: 'rgba(230,61,46,0.05)',
  },
  iconTile: {
    width: 40,
    height: 40,
    borderRadius: 10,
    backgroundColor: tt.emberDim,
    borderWidth: 1,
    borderColor: 'rgba(255,106,44,0.32)',
    alignItems: 'center',
    justifyContent: 'center',
  },
  label: {
    marginTop: sp.s4,
    fontFamily: font.uiHeavy,
    fontSize: fz.rowTitle,
    color: tt.text,
  },
  sub: {
    marginTop: 4,
    fontFamily: font.uiMed,
    fontSize: fz.body,
    color: tt.text2,
  },
});
