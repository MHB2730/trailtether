// Trailtether — 6-tab shell.
//
// Matches the handoff's <BottomNav> exactly:
//   home, map, tools, community, teams, profile
//
// Each active tab gets an ember-coloured icon + label and a 28×3px ember
// "pip" rendered as a top border on the active tab. Inactive tabs are
// tt.text3. A 130×4 rounded gesture-bar sits at the very bottom of the
// nav (drawn via tabBarStyle below).
//
// expo-router's Tabs uses React Navigation's bottom tab navigator under
// the hood, so we customise via `tabBarStyle` / `tabBarItemStyle` /
// `tabBarLabel` / `tabBarIcon`.

import { Tabs } from 'expo-router';
import React from 'react';
import { StyleSheet, View } from 'react-native';
import { AuthGate } from '@/components/AuthGate';
import { Icon, IconName } from '@components/Icon';
import { font, ls, tt } from '@theme/tokens';

interface TabSpec {
  name: string;
  label: string;
  icon: IconName;
}

const TABS: TabSpec[] = [
  { name: 'index', label: 'Home', icon: 'home' },
  { name: 'map', label: 'Map', icon: 'map' },
  { name: 'tools', label: 'Tools', icon: 'compass' },
  { name: 'community', label: 'Community', icon: 'message' },
  { name: 'teams', label: 'Teams', icon: 'people' },
  { name: 'profile', label: 'Profile', icon: 'user' },
];

export default function TabsLayout() {
  // AuthGate hydrates the auth store + redirects to /sign-in when there's
  // no session. Once signed-in, the 6-tab shell renders.
  return (
    <AuthGate>
      <Tabs
        screenOptions={{
          headerShown: false,
          tabBarStyle: styles.tabBar,
          tabBarItemStyle: styles.tabItem,
          tabBarShowLabel: true,
          tabBarActiveTintColor: tt.ember,
          tabBarInactiveTintColor: tt.text3,
          tabBarLabelStyle: styles.label,
        }}
      >
        {TABS.map((t) => (
          <Tabs.Screen
            key={t.name}
            name={t.name}
            options={{
              title: t.label,
              tabBarLabel: t.label,
              tabBarIcon: ({ focused, color }) => (
                <TabIcon name={t.icon} focused={focused} color={color} />
              ),
            }}
          />
        ))}
      </Tabs>
    </AuthGate>
  );
}

function TabIcon({
  name,
  focused,
  color,
}: {
  name: IconName;
  focused: boolean;
  color: string;
}) {
  return (
    <View style={styles.iconWrap}>
      {/* 28×3 ember pip drawn at the top edge of the active tab. */}
      {focused && <View style={styles.pip} />}
      <Icon name={name} size={19} color={color} />
    </View>
  );
}

const styles = StyleSheet.create({
  tabBar: {
    backgroundColor: tt.bg2,
    borderTopWidth: 1,
    borderTopColor: tt.line2,
    height: 84,
    paddingTop: 8,
    paddingBottom: 12,
  },
  tabItem: {
    paddingVertical: 0,
  },
  label: {
    fontFamily: font.uiSemi,
    fontSize: 8.5,
    letterSpacing: ls.monoTight * 8.5,
    marginTop: 2,
  },
  iconWrap: {
    alignItems: 'center',
    justifyContent: 'center',
    width: 32,
    paddingTop: 6,
  },
  pip: {
    position: 'absolute',
    top: -8,
    width: 28,
    height: 3,
    borderRadius: 2,
    backgroundColor: tt.ember,
  },
});
