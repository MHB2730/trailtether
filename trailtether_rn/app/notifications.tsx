// Trailtether — Notifications.
//
// Backed by the `notifications` table (resolved BLOCKERS.md #12). Reads
// the most-recent 100 rows for the current user, supports a filter chip
// row, and dispatches `markNotificationRead` when an item is tapped.

import React, { useState } from 'react';
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
import { ErrorState, LoadingState } from '@components/primitives/States';
import { Icon, type IconName } from '@components/Icon';
import { markNotificationRead, useNotifications } from '@/data/hooks';
import { font, fz, ls, sp, tt } from '@theme/tokens';
import type { Notification } from '@/data/types';

type Filter = 'all' | 'unread' | 'urgent';

export default function NotificationsScreen() {
  const router = useRouter();
  const feed = useNotifications();
  const [filter, setFilter] = useState<Filter>('all');

  const items: Notification[] = !feed.data
    ? []
    : filter === 'unread'
      ? feed.data.filter((n) => !n.read)
      : filter === 'urgent'
        ? feed.data.filter((n) => n.urgent)
        : feed.data;

  const handlePress = async (n: Notification) => {
    if (!n.read) {
      try {
        await markNotificationRead(n.id);
        void feed.refetch();
      } catch {
        // RPC failure is non-fatal — UI stays unread.
      }
    }
  };

  return (
    <ScreenShell>
      <TTAppBar
        big
        title="Notifications"
        sub="ALERTS · HAZARDS · UPDATES"
        leftIcon="chevron-up"
        onPressLeft={() => router.back()}
        right={<IconBtn name="check" />}
      />
      <ScrollView
        contentContainerStyle={styles.body}
        showsVerticalScrollIndicator={false}
      >
        <View style={{ marginTop: sp.s4 }}>
          <ChipRow
            fitted
            value={filter}
            onChange={(id) => setFilter(id as Filter)}
            items={[
              { id: 'all', label: 'All', count: feed.data?.length ?? 0 },
              { id: 'unread', label: 'Unread', count: feed.data?.filter((n) => !n.read).length ?? 0 },
              { id: 'urgent', label: 'Urgent', count: feed.data?.filter((n) => n.urgent).length ?? 0 },
            ]}
          />
        </View>

        {feed.loading && <LoadingState style={{ marginTop: sp.s6 }} />}
        {feed.error && !feed.loading && (
          <ErrorState error={feed.error} onRetry={feed.refetch} />
        )}

        <View style={{ marginTop: sp.s4 }}>
          {items.length === 0 && !feed.loading && !feed.error && (
            <Text style={styles.empty}>No alerts right now.</Text>
          )}
          {items.map((n) => {
            const tone = n.urgent ? tt.red : kindColor(n.kind);
            return (
              <Pressable
                key={n.id}
                onPress={() => void handlePress(n)}
                style={({ pressed }) => [pressed && { opacity: 0.85 }]}
              >
                <Card tight style={[{ marginTop: sp.s3 }, !n.read && styles.unread]}>
                  <View style={styles.row}>
                    <View
                      style={[
                        styles.iconTile,
                        { backgroundColor: `${tone}1f`, borderColor: `${tone}55` },
                      ]}
                    >
                      <Icon name={kindIcon(n.kind)} size={14} color={tone} />
                    </View>
                    <View style={{ flex: 1, minWidth: 0 }}>
                      <Text style={styles.title} numberOfLines={1}>
                        {n.title}
                      </Text>
                      <Text style={styles.sub} numberOfLines={2}>
                        {n.sub}
                      </Text>
                      {n.action && (
                        <Text style={styles.action}>{n.action.toUpperCase()} →</Text>
                      )}
                    </View>
                    <View style={{ alignItems: 'flex-end' }}>
                      {n.urgent && <Text style={[styles.severity, { color: tt.red }]}>URGENT</Text>}
                      <Text style={styles.time}>{n.timeLabel}</Text>
                      {!n.read && <View style={[styles.unreadDot, { backgroundColor: tone }]} />}
                    </View>
                  </View>
                </Card>
              </Pressable>
            );
          })}
        </View>
      </ScrollView>
    </ScreenShell>
  );
}

function kindIcon(kind: Notification['kind']): IconName {
  switch (kind) {
    case 'weather':     return 'wind';
    case 'hazard':      return 'alert';
    case 'team':        return 'people';
    case 'mention':     return 'message';
    case 'achievement': return 'flame';
    case 'review':      return 'check';
    default:            return 'bell';
  }
}

function kindColor(kind: Notification['kind']) {
  switch (kind) {
    case 'weather':     return tt.blue;
    case 'hazard':      return tt.amber;
    case 'team':        return tt.ember;
    case 'achievement': return tt.green;
    default:            return tt.text2;
  }
}

const styles = StyleSheet.create({
  body: { paddingHorizontal: sp.screen, paddingBottom: sp.s11 },
  row: { flexDirection: 'row', alignItems: 'center', gap: sp.s5 },
  iconTile: {
    width: 34,
    height: 34,
    borderRadius: 9,
    borderWidth: 1,
    alignItems: 'center',
    justifyContent: 'center',
  },
  title: {
    fontFamily: font.uiBold,
    fontSize: fz.rowTitle,
    color: tt.text,
  },
  sub: {
    marginTop: 2,
    fontFamily: font.uiMed,
    fontSize: fz.body,
    color: tt.text2,
  },
  severity: {
    fontFamily: font.monoBold,
    fontSize: 9,
    letterSpacing: ls.monoWide * 9,
  },
  time: {
    marginTop: 2,
    fontFamily: font.monoSemi,
    fontSize: 9.5,
    color: tt.text3,
    letterSpacing: ls.monoTight * 9.5,
  },
  empty: {
    textAlign: 'center',
    marginTop: sp.s9,
    fontFamily: font.uiMed,
    fontSize: fz.body,
    color: tt.text3,
  },
  unread: {
    borderColor: 'rgba(255,106,44,0.32)',
  },
  unreadDot: {
    marginTop: 6,
    width: 8,
    height: 8,
    borderRadius: 4,
  },
  action: {
    marginTop: 4,
    fontFamily: font.monoBold,
    fontSize: 9.5,
    color: tt.ember,
    letterSpacing: ls.monoWide * 9.5,
  },
});
