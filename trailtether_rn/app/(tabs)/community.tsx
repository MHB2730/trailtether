// Trailtether — Community (tab).
//
// Segmented "Feed" / "Chat". Feed reads the `posts` table (resolved
// BLOCKERS #13). Chat reads `chat_messages` for the user's first
// team. The Chat half still depends on team-as-room mapping — a
// dedicated `chat_rooms` table is a future improvement but the
// existing schema works for one team-thread per user.

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
import { Segmented } from '@components/primitives/Segmented';
import { BlockedSection } from '@components/primitives/BlockedSection';
import { ErrorState, LoadingState } from '@components/primitives/States';
import { Icon } from '@components/Icon';
import {
  togglePostLike,
  useChatMessages,
  useMyTeams,
  usePosts,
} from '@/data/hooks';
import { colorForUid } from '@/data/adapters';
import { font, fz, ls, sp, tt } from '@theme/tokens';
import type { ChatMessage, FeedPost } from '@/data/types';

type Tab = 'feed' | 'chat';

export default function CommunityTab() {
  const router = useRouter();
  const [tab, setTab] = useState<Tab>('feed');
  const feed = usePosts();
  const teams = useMyTeams();
  const firstTeamId = teams.data?.[0]?.id ?? null;
  const chat = useChatMessages(firstTeamId);
  const [likeBusy, setLikeBusy] = useState<string | null>(null);

  return (
    <ScreenShell>
      <TTAppBar
        sub="FEED · CHAT"
        right={<IconBtn name="search" onPress={() => router.push('/search')} />}
      />
      <View style={styles.head}>
        <Segmented
          options={['Feed', 'Chat']}
          active={tab === 'feed' ? 0 : 1}
          onChange={(i) => setTab(i === 0 ? 'feed' : 'chat')}
        />
      </View>
      <ScrollView
        contentContainerStyle={styles.body}
        showsVerticalScrollIndicator={false}
      >
        {tab === 'feed' && <FeedTab />}
        {tab === 'chat' && (
          <ChatPane
            chat={chat.data ?? []}
            loading={chat.loading}
            error={chat.error}
            onRetry={chat.refetch}
            teamName={teams.data?.[0]?.name ?? null}
            haveTeam={!!firstTeamId}
          />
        )}
      </ScrollView>
    </ScreenShell>
  );

  function FeedTab() {
    const onLike = async (post: FeedPost, liked: boolean) => {
      if (likeBusy) return;
      setLikeBusy(post.id);
      try {
        await togglePostLike(post.id, liked);
        void feed.refetch();
      } catch {
        // Non-fatal — UI stays in the previous state.
      } finally {
        setLikeBusy(null);
      }
    };
    return (
      <>
        <Text style={styles.heading}>COMMUNITY · LIVE</Text>
        {feed.loading && <LoadingState />}
        {feed.error && !feed.loading && (
          <ErrorState error={feed.error} onRetry={feed.refetch} />
        )}
        {feed.data && feed.data.length === 0 && !feed.loading && (
          <Text style={styles.empty}>
            No posts yet. Be the first — community feed is wired and waiting.
          </Text>
        )}
        {feed.data?.map((p) => (
          <Card key={p.id} style={{ marginTop: sp.s3 }}>
            <View style={styles.postHeader}>
              <View style={[styles.avatar, { backgroundColor: p.author.color }]}>
                <Text style={styles.avatarText}>{p.author.initials}</Text>
              </View>
              <View style={{ flex: 1 }}>
                <Text style={styles.title} numberOfLines={1}>
                  {p.author.name}
                </Text>
                <Text style={styles.postMeta} numberOfLines={1}>
                  {p.timeLabel}
                  {p.location ? ` · ${p.location.toUpperCase()}` : ''}
                </Text>
              </View>
              {p.hazard && (
                <View style={styles.hazardBadge}>
                  <Icon name="alert" size={11} color={tt.amber} />
                  <Text style={styles.hazardText}>HAZARD</Text>
                </View>
              )}
            </View>
            {p.text.length > 0 && (
              <Text style={styles.postBody}>{p.text}</Text>
            )}
            {p.stats && (
              <View style={styles.postStats}>
                <Text style={styles.postStat}>{p.stats.distLabel}</Text>
                <Text style={styles.postStat}>{p.stats.gainLabel}</Text>
                <Text style={styles.postStat}>{p.stats.timeLabel}</Text>
              </View>
            )}
            <View style={styles.postActions}>
              <Pressable
                onPress={() => void onLike(p, false)}
                hitSlop={6}
                style={({ pressed }) => [styles.actionBtn, pressed && { opacity: 0.7 }]}
              >
                <Icon name="heart" size={13} color={tt.text2} />
                <Text style={styles.actionText}>{p.likes}</Text>
              </Pressable>
              <View style={styles.actionBtn}>
                <Icon name="message" size={13} color={tt.text2} />
                <Text style={styles.actionText}>{p.comments}</Text>
              </View>
              {p.attachment?.kind === 'gpx' && (
                <View style={styles.actionBtn}>
                  <Icon name="route" size={13} color={tt.ember} />
                  <Text style={[styles.actionText, { color: tt.ember }]}>
                    {p.attachment.filename}
                  </Text>
                </View>
              )}
            </View>
          </Card>
        ))}
      </>
    );
  }
}

function ChatPane({
  chat,
  loading,
  error,
  onRetry,
  teamName,
  haveTeam,
}: {
  chat: ChatMessage[];
  loading: boolean;
  error: string | null;
  onRetry: () => Promise<void>;
  teamName: string | null;
  haveTeam: boolean;
}) {
  if (!haveTeam) {
    return (
      <BlockedSection
        number={16}
        title="No team room to chat in"
        note="Chat rooms are scoped to teams. Join one to see this thread populate."
      />
    );
  }
  return (
    <View>
      <Text style={styles.heading}>{(teamName ?? 'TEAM').toUpperCase()} · CHAT</Text>
      {loading && <LoadingState />}
      {error && !loading && <ErrorState error={error} onRetry={onRetry} />}
      {chat.length === 0 && !loading && !error && (
        <Text style={styles.empty}>No messages in this room yet.</Text>
      )}
      {chat.map((m) => (
        <View key={m.id} style={[styles.msgRow, m.mine && styles.msgRowMine]}>
          {!m.mine && (
            <View style={[styles.avatar, { backgroundColor: colorForUid(m.sender.id) }]}>
              <Text style={styles.avatarText}>{m.sender.initials}</Text>
            </View>
          )}
          <View style={[styles.bubble, m.mine && styles.bubbleMine]}>
            {!m.mine && <Text style={styles.senderName}>{m.sender.name}</Text>}
            <Text style={[styles.msgText, m.mine && { color: '#1a0d04' }]}>{m.text}</Text>
            <Text style={[styles.msgTime, m.mine && { color: 'rgba(26,13,4,0.55)' }]}>
              {m.timeLabel}
            </Text>
          </View>
        </View>
      ))}
    </View>
  );
}

const styles = StyleSheet.create({
  head: { paddingHorizontal: sp.screen, paddingBottom: sp.s4 },
  body: { paddingHorizontal: sp.screen, paddingBottom: sp.s11 },
  heading: {
    marginTop: sp.s5,
    fontFamily: font.uiBold,
    fontSize: 11,
    color: tt.text2,
    letterSpacing: ls.monoWide * 11,
    textTransform: 'uppercase',
  },
  row: { flexDirection: 'row', alignItems: 'center', gap: sp.s4 },
  title: { fontFamily: font.uiBold, fontSize: fz.rowTitle, color: tt.text },
  sub: { marginTop: 2, fontFamily: font.uiMed, fontSize: fz.body, color: tt.text2 },
  time: {
    fontFamily: font.monoBold,
    fontSize: 10,
    color: tt.text3,
    letterSpacing: ls.monoTight * 10,
  },
  empty: {
    marginTop: sp.s7,
    textAlign: 'center',
    fontFamily: font.uiMed,
    fontSize: fz.body,
    color: tt.text3,
  },
  msgRow: {
    marginTop: sp.s4,
    flexDirection: 'row',
    alignItems: 'flex-end',
    gap: sp.s3,
  },
  msgRowMine: { justifyContent: 'flex-end' },
  avatar: {
    width: 30,
    height: 30,
    borderRadius: 15,
    alignItems: 'center',
    justifyContent: 'center',
  },
  avatarText: {
    fontFamily: font.uiHeavy,
    fontSize: 12,
    color: '#1a0d04',
    letterSpacing: ls.tight * 12,
  },
  bubble: {
    maxWidth: '76%',
    padding: sp.s5,
    backgroundColor: tt.surf,
    borderRadius: 14,
    borderWidth: 1,
    borderColor: tt.line,
  },
  bubbleMine: {
    backgroundColor: tt.ember,
    borderColor: tt.ember2,
  },
  senderName: {
    fontFamily: font.uiBold,
    fontSize: 10.5,
    color: tt.text2,
    letterSpacing: ls.monoTight * 10.5,
    marginBottom: 4,
  },
  msgText: {
    fontFamily: font.uiSemi,
    fontSize: fz.body2,
    color: tt.text,
    lineHeight: 18,
  },
  msgTime: {
    marginTop: 4,
    fontFamily: font.monoBold,
    fontSize: 9,
    color: tt.text3,
    letterSpacing: ls.monoTight * 9,
    alignSelf: 'flex-end',
  },
  postHeader: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: sp.s4,
    marginBottom: sp.s4,
  },
  postMeta: {
    marginTop: 2,
    fontFamily: font.monoSemi,
    fontSize: fz.micro2,
    color: tt.text3,
    letterSpacing: ls.monoTight * fz.micro2,
  },
  postBody: {
    fontFamily: font.uiSemi,
    fontSize: fz.body2,
    color: tt.text,
    lineHeight: 19,
  },
  postStats: {
    marginTop: sp.s4,
    flexDirection: 'row',
    gap: sp.s5,
  },
  postStat: {
    fontFamily: font.monoBold,
    fontSize: fz.body,
    color: tt.text2,
    letterSpacing: ls.monoTight * fz.body,
  },
  postActions: {
    marginTop: sp.s5,
    flexDirection: 'row',
    gap: sp.s6,
    paddingTop: sp.s4,
    borderTopWidth: 1,
    borderTopColor: tt.line,
  },
  actionBtn: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 5,
  },
  actionText: {
    fontFamily: font.monoBold,
    fontSize: fz.body,
    color: tt.text2,
    letterSpacing: ls.monoTight * fz.body,
  },
  hazardBadge: {
    flexDirection: 'row',
    alignItems: 'center',
    gap: 4,
    paddingVertical: 2,
    paddingHorizontal: 7,
    borderRadius: 5,
    backgroundColor: 'rgba(242,169,59,0.15)',
    borderWidth: 1,
    borderColor: 'rgba(242,169,59,0.45)',
  },
  hazardText: {
    fontFamily: font.monoBold,
    fontSize: 8.5,
    color: tt.amber,
    letterSpacing: ls.monoWide * 8.5,
  },
});
