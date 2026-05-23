// Trailtether — Settings.
//
// Seven grouped sections per the design source. Each row is a
// `SettingRow` from the design components. Toggles are uncontrolled
// today (BLOCKERS.md #15 — no `notification_settings` write path
// from the RN client yet); when that lands the matching SettingRow
// instances can pass `toggleOn` + `onToggle` to wire them up.
//
// Sign-out is the only row with live behaviour today: it calls the
// auth store's `signOut()` and the AuthGate sends the user back to
// /welcome.

import React from 'react';
import { Pressable, StyleSheet, Text, View } from 'react-native';
import { useRouter } from 'expo-router';
import { ScreenShell } from '@components/primitives/ScreenShell';
import { TTAppBar, IconBtn } from '@components/primitives/TTAppBar';
import { SettingRow, SettingsGroup } from '@components/design/SettingRow';
import { BlockedSection } from '@components/primitives/BlockedSection';
import { Icon } from '@components/Icon';
import { useAuth } from '@/store/auth';
import { font, fz, ls, radius, sp, tt } from '@theme/tokens';

export default function SettingsScreen() {
  const router = useRouter();
  const signOut = useAuth((s) => s.signOut);
  const email = useAuth((s) => s.user?.email);

  const handleSignOut = async () => {
    await signOut();
    router.replace('/welcome');
  };

  return (
    <ScreenShell>
      <TTAppBar
        big
        title="Settings"
        sub="ACCOUNT · PRIVACY · TETHER"
        leftIcon="chevron-up"
        onPressLeft={() => router.back()}
        right={<IconBtn name="search" />}
      />
      <View style={styles.body}>
        <BlockedSection
          number={15}
          title="Toggles aren't persisted yet"
          note="Settings UI is wired; notification_settings + units write paths land in BLOCKERS.md #15."
        />

        <SettingsGroup title="Tether">
          <SettingRow
            icon="tether"
            label="Base-camp pairing"
            sub="Manage paired PCs"
            value="Manage"
            onPress={() => {}}
          />
          <SettingRow
            icon="eye"
            label="Live tracking"
            sub="Always-on when hiking"
            toggle
          />
          <SettingRow
            icon="bell"
            label="Notifications"
            sub="Alerts, weather, hazards"
            value="On"
            isLast
            onPress={() => router.push('/notifications')}
          />
        </SettingsGroup>

        <SettingsGroup title="Display">
          <SettingRow
            icon="layers"
            label="Units"
            sub="Metric or imperial"
            value="Metric"
            onPress={() => {}}
          />
          <SettingRow
            icon="route"
            label="Difficulty scale"
            sub="Four-level (Easy → Technical)"
            value="Default"
            isLast
            onPress={() => {}}
          />
        </SettingsGroup>

        <SettingsGroup title="Maps & data">
          <SettingRow
            icon="map"
            label="Offline maps"
            sub="Drakensberg downloaded"
            value="Manage"
            onPress={() => {}}
          />
          <SettingRow
            icon="history"
            label="Hike history"
            sub="Export GPX bundle"
            value="Export"
            onPress={() => {}}
          />
          <SettingRow
            icon="heart"
            label="Health Connect"
            sub="Synced 2m ago"
            synced
            isLast
            onPress={() => {}}
          />
        </SettingsGroup>

        <SettingsGroup title="Trail recording">
          <SettingRow
            icon="radio"
            label="GPS interval"
            sub="Fix every 4 seconds"
            value="4 s"
            onPress={() => {}}
          />
          <SettingRow
            icon="flame"
            label="Speed colouring"
            sub="Colour the line by pace"
            toggle
            isLast
          />
        </SettingsGroup>

        <SettingsGroup title="Privacy">
          <SettingRow
            icon="shield"
            label="Watcher list"
            sub="Who can see your tether"
            value="Manage"
            onPress={() => {}}
          />
          <SettingRow
            icon="user"
            label="Anonymous reports"
            sub="Hide your name on hazards"
            toggle
            isLast
          />
        </SettingsGroup>

        <SettingsGroup title="About">
          <SettingRow
            icon="alert"
            label="App version"
            sub="Trailtether v3.1.3"
            value="OK"
          />
          <SettingRow
            icon="user"
            label="Signed in as"
            sub={email ?? '—'}
            isLast
          />
        </SettingsGroup>

        <Pressable
          onPress={handleSignOut}
          style={({ pressed }) => [
            styles.signOut,
            pressed && { opacity: 0.85 },
          ]}
        >
          <Icon name="chevron-up" size={14} color={tt.red} />
          <Text style={styles.signOutText}>SIGN OUT</Text>
        </Pressable>
      </View>
    </ScreenShell>
  );
}

const styles = StyleSheet.create({
  body: { paddingHorizontal: sp.screen, paddingBottom: sp.s7 },
  signOut: {
    marginTop: sp.s10,
    flexDirection: 'row',
    alignItems: 'center',
    justifyContent: 'center',
    gap: sp.s3,
    paddingVertical: sp.s6,
    borderRadius: radius.md,
    backgroundColor: 'rgba(230,61,46,0.10)',
    borderWidth: 1,
    borderColor: 'rgba(230,61,46,0.32)',
  },
  signOutText: {
    fontFamily: font.monoBold,
    fontSize: fz.caption,
    color: tt.red,
    letterSpacing: ls.monoWide * fz.caption,
  },
});
