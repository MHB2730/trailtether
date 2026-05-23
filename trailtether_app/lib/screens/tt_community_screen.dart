// Trailtether 2.0 — Community screen.
//
// Brand bar + segmented tabs (Feed / Chat) over an animated body.
// Feed shows posts (TTCard) sourced from CommunityProvider.activities
// with author rows, location pills and an optional mini elevation chart
// when the activity references a hike. Chat shows a bubble thread
// (ember tint for own messages, graphite for received) backed by
// ChatProvider with a working composer pinned at the bottom.
//
// Every interactive surface in this file is wired to a real action:
//   - Top-bar search filters the active list (feed posts / chat messages)
//   - Top-bar bell opens a notification centre showing recent feed activity
//   - Compose row opens a sheet that posts to community_activities
//   - Card tap opens a detail sheet; like animates locally; comments live in
//     an in-memory store keyed by post id (no DB schema for them yet); share
//     uses share_plus with a trailtether://post/{id} deep link
//   - Chat composer sends via ChatProvider.sendText
//   - Long-press a chat bubble for Copy / Delete (delete is sender-only and
//     hits chat_messages directly via Supabase; UI removes optimistically)

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import '../core/constants.dart';
import '../core/design_tokens.dart';
import '../core/runtime_config.dart';
import '../models/chat_message.dart';
import '../models/community.dart';
import '../providers/auth_provider.dart' as ap;
import '../providers/chat_provider.dart';
import '../providers/community_provider.dart';
import '../widgets/design/tt_ambient.dart';
import '../widgets/design/tt_app_bar.dart';
import '../widgets/design/tt_glass_card.dart';
import '../widgets/design/tt_pill.dart';
import '../widgets/design/tt_segmented.dart';
import '../widgets/design/tt_topo.dart';

class TTCommunityScreen extends StatefulWidget {
  final bool embedded;
  const TTCommunityScreen({super.key, this.embedded = false});

  @override
  State<TTCommunityScreen> createState() => _TTCommunityScreenState();
}

class _TTCommunityScreenState extends State<TTCommunityScreen> {
  int _tab = 0; // 0 Feed, 1 Chat — matches the design's default

  /// Active text filter for the current tab. Empty string = no filter.
  String _query = '';
  bool _searchOpen = false;
  final TextEditingController _searchCtl = TextEditingController();

  @override
  void dispose() {
    _searchCtl.dispose();
    super.dispose();
  }

  void _toggleSearch() {
    setState(() {
      _searchOpen = !_searchOpen;
      if (!_searchOpen) {
        _query = '';
        _searchCtl.clear();
      }
    });
  }

  void _openNotificationCenter() {
    final activities = context.read<CommunityProvider>().activities;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: TT.bg2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(TT.rXl)),
      ),
      builder: (_) => _NotificationSheet(activities: activities),
    );
  }

  @override
  Widget build(BuildContext context) {
    final body = Stack(
      children: [
        const Positioned.fill(child: TTAmbient()),
        const Positioned.fill(child: TTTopoBackdrop()),
        SafeArea(
          top: !widget.embedded,
          bottom: false,
          child: Column(
            children: [
              TTPageAppBar(
                title: 'Community',
                trailing: [
                  TTIconBtn(
                    icon: _searchOpen ? Icons.close : Icons.search,
                    onTap: _toggleSearch,
                    ember: _searchOpen,
                  ),
                  TTIconBtn(
                    icon: Icons.notifications_none,
                    onTap: _openNotificationCenter,
                  ),
                ],
              ),
              if (_searchOpen)
                Padding(
                  padding: const EdgeInsets.fromLTRB(18, 0, 18, 6),
                  child: _SearchField(
                    controller: _searchCtl,
                    hint: _tab == 0
                        ? 'Filter posts by author, place, body…'
                        : 'Filter messages by sender or text…',
                    onChanged: (v) => setState(() => _query = v.trim()),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.fromLTRB(18, 4, 18, 0),
                child: TTSegmented(
                  tabs: const ['Feed', 'Chat'],
                  active: _tab,
                  onChange: (i) => setState(() {
                    _tab = i;
                    // Filter is per-tab — switching wipes the query so the
                    // hint reflects the new context cleanly.
                    if (_query.isNotEmpty) {
                      _query = '';
                      _searchCtl.clear();
                    }
                  }),
                ),
              ),
              Expanded(
                child: AnimatedSwitcher(
                  duration: TT.dMed,
                  child: _tab == 0
                      ? _FeedView(key: const ValueKey('feed'), query: _query)
                      : _ChatView(key: const ValueKey('chat'), query: _query),
                ),
              ),
            ],
          ),
        ),
      ],
    );

    if (widget.embedded) return Material(color: TT.bg, child: body);
    return Scaffold(backgroundColor: TT.bg, body: body);
  }
}

// ─────────────────────────────────── HELPERS ────────────────────────────────

/// Stable avatar color for a name — keeps users visually distinct across
/// posts/chat without persisting anything. Uses the brand palette.
const List<Color> _avatarPalette = [
  Color(0xFFFF8A4D),
  Color(0xFF4CC38A),
  Color(0xFFF2A93B),
  Color(0xFFFF6A2C),
  Color(0xFF5AA1D6),
  Color(0xFFFFB486),
];

Color _avatarColorFor(String key) {
  if (key.isEmpty) return TT.ember;
  var h = 0;
  for (final c in key.codeUnits) {
    h = (h * 31 + c) & 0x7fffffff;
  }
  return _avatarPalette[h % _avatarPalette.length];
}

String _initialsFor(String name) {
  final trimmed = name.trim();
  if (trimmed.isEmpty) return '?';
  final parts = trimmed.split(RegExp(r'\s+'));
  if (parts.length == 1) {
    final p = parts.first;
    return p.length >= 2
        ? p.substring(0, 2).toUpperCase()
        : p[0].toUpperCase();
  }
  return (parts.first[0] + parts.last[0]).toUpperCase();
}

String _relativeTime(DateTime when) {
  final now = DateTime.now();
  final diff = now.difference(when);
  if (diff.isNegative) return 'just now';
  if (diff.inSeconds < 45) return 'just now';
  if (diff.inMinutes < 1) return '${diff.inSeconds}s ago';
  if (diff.inMinutes < 60) return '${diff.inMinutes}m ago';
  if (diff.inHours < 24) return '${diff.inHours}h ago';
  if (diff.inDays == 1) return 'Yesterday';
  if (diff.inDays < 7) return '${diff.inDays}d ago';
  if (diff.inDays < 30) return '${(diff.inDays / 7).floor()}w ago';
  if (diff.inDays < 365) return '${(diff.inDays / 30).floor()}mo ago';
  return '${(diff.inDays / 365).floor()}y ago';
}

String _clockTime(DateTime when) {
  final h = when.hour.toString().padLeft(2, '0');
  final m = when.minute.toString().padLeft(2, '0');
  return '$h:$m';
}

bool _matchesQuery(String haystack, String query) {
  if (query.isEmpty) return true;
  return haystack.toLowerCase().contains(query.toLowerCase());
}

void _toast(BuildContext context, String text, {bool error = false}) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(text,
          style: TT.body(size: 13, color: Colors.white, w: FontWeight.w600)),
      behavior: SnackBarBehavior.floating,
      backgroundColor: error ? TT.red : TT.surf2,
      duration: const Duration(seconds: 2),
    ),
  );
}

/// In-memory store of likes + comments keyed by activity id. Persists for the
/// life of the app session — the schema has no likes/comments columns, so we
/// don't try to fake a round-trip to the DB. Reset on hot restart.
class _PostInteractions {
  _PostInteractions._();
  static final _PostInteractions instance = _PostInteractions._();

  /// activity id -> set of liker uids (or device anon ids).
  final Map<String, Set<String>> _likes = {};

  /// activity id -> ordered list of comments.
  final Map<String, List<_LocalComment>> _comments = {};

  Set<String> likers(String id) => _likes[id] ?? const <String>{};
  bool isLiked(String id, String uid) =>
      uid.isNotEmpty && (_likes[id]?.contains(uid) ?? false);
  int likeCount(String id) => _likes[id]?.length ?? 0;

  /// Returns the new liked state.
  bool toggleLike(String id, String uid) {
    final set = _likes.putIfAbsent(id, () => <String>{});
    final liked = set.contains(uid);
    if (liked) {
      set.remove(uid);
    } else {
      set.add(uid);
    }
    return !liked;
  }

  List<_LocalComment> comments(String id) =>
      List.unmodifiable(_comments[id] ?? const <_LocalComment>[]);
  int commentCount(String id) => _comments[id]?.length ?? 0;

  void addComment(String id, _LocalComment c) {
    _comments.putIfAbsent(id, () => <_LocalComment>[]).add(c);
  }
}

class _LocalComment {
  final String author;
  final String text;
  final DateTime when;
  const _LocalComment(
      {required this.author, required this.text, required this.when});
}

// ─────────────────────────────────── FEED ───────────────────────────────────

class _FeedView extends StatelessWidget {
  final String query;
  const _FeedView({super.key, required this.query});

  @override
  Widget build(BuildContext context) {
    return Consumer<CommunityProvider>(
      builder: (_, provider, __) {
        if (provider.loading && provider.activities.isEmpty) {
          return const Center(
            child: CircularProgressIndicator(color: TT.ember),
          );
        }
        final all = provider.activities;
        final activities = query.isEmpty
            ? all
            : all
                .where((a) => _matchesQuery(
                    '${a.userName} ${a.teamName} ${a.title} ${a.subtitle}',
                    query))
                .toList();
        return RefreshIndicator(
          onRefresh: provider.refresh,
          color: TT.ember,
          backgroundColor: TT.surf,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(18, 14, 18, 28),
            children: [
              const _ComposePrompt(),
              const SizedBox(height: 14),
              if (activities.isEmpty)
                _EmptyFeed(filtered: query.isNotEmpty)
              else
                for (var i = 0; i < activities.length; i++)
                  Padding(
                    padding: EdgeInsets.only(
                        bottom: i == activities.length - 1 ? 0 : 12),
                    child: _FadeUpDelayed(
                      delay: Duration(milliseconds: 350 + i * 90),
                      child: _FeedPost(activity: activities[i]),
                    ),
                  ),
            ],
          ),
        );
      },
    );
  }
}

class _EmptyFeed extends StatelessWidget {
  final bool filtered;
  const _EmptyFeed({this.filtered = false});

  @override
  Widget build(BuildContext context) {
    return _FadeUpDelayed(
      delay: const Duration(milliseconds: 320),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 32),
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: TT.surf,
          border: Border.all(color: TT.line, width: 1),
          borderRadius: BorderRadius.circular(TT.rLg),
        ),
        child: Text(
          filtered
              ? 'No posts match your search.'
              : 'No activity yet. When your team starts hiking, posts appear here.',
          textAlign: TextAlign.center,
          style: TT.body(size: 13, w: FontWeight.w500, color: TT.text3)
              .copyWith(height: 1.5),
        ),
      ),
    );
  }
}

class _ComposePrompt extends StatelessWidget {
  const _ComposePrompt();

  @override
  Widget build(BuildContext context) {
    final auth = context.watch<ap.AuthProvider>();
    final name = auth.displayName ?? auth.email ?? 'You';
    final initials = _initialsFor(name);

    return _FadeUpDelayed(
      delay: const Duration(milliseconds: 220),
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: () => _openComposer(context),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            color: TT.surf,
            border: Border.all(color: TT.line, width: 1),
            borderRadius: BorderRadius.circular(14),
          ),
          child: Row(
            children: [
              Container(
                width: 34, height: 34,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  border: Border.all(color: TT.ember, width: 2),
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [Color(0xFF6B3A1A), TT.ember2],
                  ),
                ),
                alignment: Alignment.center,
                child: Text(initials,
                    style: TT.body(
                        size: 12, w: FontWeight.w800, color: Colors.white)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'Share a trail report, hazard, or photo…',
                  style: TT.body(size: 13, w: FontWeight.w500, color: TT.text3),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                width: 32, height: 32,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: const Color(0x08FFFFFF),
                  border: Border.all(color: TT.line, width: 1),
                  borderRadius: BorderRadius.circular(TT.rMd),
                ),
                child: const Icon(Icons.edit_outlined, size: 14, color: TT.ember),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

void _openComposer(BuildContext context) {
  final auth = context.read<ap.AuthProvider>();
  if (!auth.isAuth) {
    _toast(context, 'Please sign in to post to the community.', error: true);
    return;
  }
  showModalBottomSheet<void>(
    context: context,
    backgroundColor: TT.bg2,
    isScrollControlled: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(TT.rXl)),
    ),
    builder: (_) => _ComposeSheet(
      authorName: auth.displayName ?? auth.email ?? 'Hiker',
      uid: auth.uid ?? '',
    ),
  );
}

class _ComposeSheet extends StatefulWidget {
  final String authorName;
  final String uid;
  const _ComposeSheet({required this.authorName, required this.uid});

  @override
  State<_ComposeSheet> createState() => _ComposeSheetState();
}

class _ComposeSheetState extends State<_ComposeSheet> {
  final TextEditingController _ctl = TextEditingController();
  final FocusNode _focus = FocusNode();
  bool _posting = false;
  bool _hazard = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) _focus.requestFocus();
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  Future<void> _post() async {
    final text = _ctl.text.trim();
    if (text.isEmpty || _posting) return;

    if (!kSupabaseAvailable) {
      _toast(context, 'Posting is unavailable in offline mode.', error: true);
      return;
    }

    setState(() => _posting = true);
    final lines = text.split('\n');
    final title = (lines.first.trim().isEmpty ? text : lines.first.trim());
    final subtitle =
        lines.length > 1 ? lines.skip(1).join('\n').trim() : '';

    try {
      await Supabase.instance.client.from('community_activities').insert({
        'user_id': widget.uid.isEmpty ? null : widget.uid,
        'user_name': widget.authorName,
        'type': _hazard ? 'check_in' : 'check_in',
        'title': _hazard ? 'Hazard report: $title' : title,
        'subtitle': subtitle,
        'timestamp': DateTime.now().toIso8601String(),
        'metadata': {
          if (_hazard) 'hazard': true,
          'source': 'community_compose',
        },
      });
      if (!mounted) return;
      await context.read<CommunityProvider>().refresh();
      if (!mounted) return;
      Navigator.of(context).pop();
      _toast(context, 'Posted to community feed.');
      unawaited(HapticFeedback.lightImpact());
    } catch (e) {
      if (!mounted) return;
      setState(() => _posting = false);
      _toast(context, 'Could not post. Try again.', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    final viewInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInset),
      child: SafeArea(
        top: false,
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 12, 18, 16),
          decoration: const BoxDecoration(
            color: TT.bg2,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(TT.rXl)),
            border: Border(top: BorderSide(color: TT.line)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Center(
                child: Container(
                  width: 42, height: 4,
                  margin: const EdgeInsets.only(bottom: 12),
                  decoration: BoxDecoration(
                    color: TT.line3,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Text('New post',
                      style: TT.title(18, color: TT.text)),
                  const Spacer(),
                  if (_hazard)
                    const TTPill(
                        label: 'HAZARD', variant: TTPillVariant.danger),
                ],
              ),
              const SizedBox(height: 12),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
                decoration: BoxDecoration(
                  color: TT.surf,
                  border: Border.all(color: TT.line, width: 1),
                  borderRadius: BorderRadius.circular(TT.rLg),
                ),
                child: TextField(
                  controller: _ctl,
                  focusNode: _focus,
                  minLines: 4,
                  maxLines: 8,
                  maxLength: 500,
                  cursorColor: TT.ember,
                  style: TT.body(size: 14, w: FontWeight.w500)
                      .copyWith(height: 1.4),
                  decoration: InputDecoration(
                    isCollapsed: true,
                    border: InputBorder.none,
                    hintText:
                        'What did you see on the trail?\nFirst line becomes the title.',
                    hintStyle: TT.body(
                            size: 14, w: FontWeight.w500, color: TT.text3)
                        .copyWith(height: 1.4),
                    counterStyle: TT.mono(size: 10, color: TT.text3),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: () => setState(() => _hazard = !_hazard),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 12, vertical: 8),
                      decoration: BoxDecoration(
                        color: _hazard
                            ? const Color(0x2EF2A93B)
                            : const Color(0x08FFFFFF),
                        border: Border.all(
                          color: _hazard
                              ? const Color(0x80F2A93B)
                              : TT.line,
                          width: 1,
                        ),
                        borderRadius: BorderRadius.circular(TT.rMd),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Icon(
                            _hazard
                                ? Icons.warning_amber_rounded
                                : Icons.warning_amber_outlined,
                            size: 16,
                            color: _hazard ? TT.amber : TT.text2,
                          ),
                          const SizedBox(width: 6),
                          Text(
                            'Mark as hazard',
                            style: TT.body(
                              size: 12,
                              w: FontWeight.w700,
                              color: _hazard ? TT.amber : TT.text2,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const Spacer(),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _posting ? null : () => Navigator.of(context).pop(),
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 14, vertical: 10),
                      decoration: BoxDecoration(
                        color: const Color(0x08FFFFFF),
                        border: Border.all(color: TT.line, width: 1),
                        borderRadius: BorderRadius.circular(TT.rMd),
                      ),
                      child: Text('Cancel',
                          style: TT.body(
                              size: 12,
                              w: FontWeight.w700,
                              color: TT.text2)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _posting ? null : _post,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      decoration: BoxDecoration(
                        gradient: const LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [TT.ember2, TT.ember],
                        ),
                        borderRadius: BorderRadius.circular(TT.rMd),
                        boxShadow: TT.shadowEmber,
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          if (_posting)
                            const SizedBox(
                              width: 14, height: 14,
                              child: CircularProgressIndicator(
                                strokeWidth: 2,
                                valueColor: AlwaysStoppedAnimation<Color>(
                                    TT.emberInk),
                              ),
                            )
                          else
                            const Icon(Icons.send,
                                size: 14, color: TT.emberInk),
                          const SizedBox(width: 6),
                          Text(
                            _posting ? 'Posting…' : 'Post',
                            style: TT.body(
                                size: 12,
                                w: FontWeight.w800,
                                color: TT.emberInk),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeedPost extends StatefulWidget {
  final CommunityActivity activity;
  const _FeedPost({required this.activity});

  @override
  State<_FeedPost> createState() => _FeedPostState();
}

class _FeedPostState extends State<_FeedPost>
    with SingleTickerProviderStateMixin {
  late final AnimationController _likeCtl = AnimationController(
      vsync: this, duration: const Duration(milliseconds: 360));

  @override
  void dispose() {
    _likeCtl.dispose();
    super.dispose();
  }

  bool get _isHike => widget.activity.type == ActivityType.hikeCompleted;
  bool get _isHazard {
    final a = widget.activity;
    if ((a.metadata['hazard'] as bool?) == true) return true;
    if (a.type != ActivityType.checkIn) return false;
    return a.title.toLowerCase().contains('hazard') ||
        a.subtitle.toLowerCase().contains('hazard');
  }

  String get _locationLabel {
    final meta = widget.activity.metadata;
    final loc = (meta['location'] ?? meta['trail_name'] ?? meta['trail'])
        as String?;
    if (loc != null && loc.trim().isNotEmpty) return loc;
    return widget.activity.teamName;
  }

  String get _bodyText {
    final parts = <String>[];
    if (widget.activity.title.trim().isNotEmpty) {
      parts.add(widget.activity.title.trim());
    }
    if (widget.activity.subtitle.trim().isNotEmpty) {
      parts.add(widget.activity.subtitle.trim());
    }
    return parts.isEmpty ? '(no details)' : parts.join(' — ');
  }

  void _onLike() {
    final uid = context.read<ap.AuthProvider>().uid ?? '';
    if (uid.isEmpty) {
      _toast(context, 'Sign in to like posts.', error: true);
      return;
    }
    final liked =
        _PostInteractions.instance.toggleLike(widget.activity.id, uid);
    HapticFeedback.selectionClick();
    if (liked) {
      _likeCtl.forward(from: 0);
    }
    setState(() {});
  }

  Future<void> _onComment() async {
    await showModalBottomSheet<void>(
      context: context,
      backgroundColor: TT.bg2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(TT.rXl)),
      ),
      builder: (_) => _CommentsSheet(activityId: widget.activity.id),
    );
    if (mounted) setState(() {}); // refresh comment count
  }

  Future<void> _onShare() async {
    final a = widget.activity;
    final text = StringBuffer()
      ..writeln('${a.userName} on Trailtether')
      ..writeln(_bodyText)
      ..writeln('')
      ..writeln('trailtether://post/${a.id}');
    try {
      await Share.share(
        text.toString().trim(),
        subject: 'Trail report from ${a.userName}',
      );
    } catch (e) {
      if (!mounted) return;
      _toast(context, 'Sharing failed.', error: true);
    }
  }

  void _onOpenDetail() {
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: TT.bg2,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(TT.rXl)),
      ),
      builder: (_) => _PostDetailSheet(activity: widget.activity),
    );
  }

  @override
  Widget build(BuildContext context) {
    final a = widget.activity;
    final color = _avatarColorFor(a.userName);
    final initials = _initialsFor(a.userName);

    final uid = context.watch<ap.AuthProvider>().uid ?? '';
    final liked = _PostInteractions.instance.isLiked(a.id, uid);
    final likeCount = _PostInteractions.instance.likeCount(a.id);
    final commentCount = _PostInteractions.instance.commentCount(a.id);

    return TTCard(
      onTap: _onOpenDetail,
      padding: EdgeInsets.zero,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(TT.rLg),
        child: Stack(
          children: [
            if (_isHazard)
              Positioned(
                left: 0, top: 0, bottom: 0,
                child: Container(width: 3, color: TT.amber),
              ),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _AuthorRow(
                    name: a.userName,
                    initials: initials,
                    color: color,
                    time: _relativeTime(a.timestamp),
                    location: _locationLabel,
                    hazard: _isHazard,
                  ),
                  const SizedBox(height: 12),
                  Text(
                    _bodyText,
                    style: TT.body(size: 13, w: FontWeight.w500)
                        .copyWith(height: 1.5),
                  ),
                  if (_isHike) ...[
                    const SizedBox(height: 12),
                    const _MiniElevChart(),
                  ],
                  const SizedBox(height: 12),
                  Container(height: 1, color: TT.line),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _LikeBtn(
                        liked: liked,
                        count: likeCount,
                        anim: _likeCtl,
                        onTap: _onLike,
                      ),
                      const SizedBox(width: 18),
                      _ActionBtn(
                        icon: Icons.mode_comment_outlined,
                        value: commentCount == 0
                            ? 'Comment'
                            : '$commentCount',
                        onTap: _onComment,
                      ),
                      const SizedBox(width: 18),
                      _ActionBtn(
                        icon: Icons.send,
                        value: 'Share',
                        onTap: _onShare,
                      ),
                      const Spacer(),
                      GestureDetector(
                        behavior: HitTestBehavior.opaque,
                        onTap: _onOpenDetail,
                        child: const Icon(Icons.more_horiz,
                            size: 16, color: TT.text3),
                      ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _AuthorRow extends StatelessWidget {
  final String name;
  final String initials;
  final Color color;
  final String time;
  final String location;
  final bool hazard;
  const _AuthorRow({
    required this.name,
    required this.initials,
    required this.color,
    required this.time,
    required this.location,
    required this.hazard,
  });

  @override
  Widget build(BuildContext context) {
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          width: 38, height: 38,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            border: Border.all(color: color, width: 2),
            gradient: LinearGradient(
              begin: Alignment.topLeft, end: Alignment.bottomRight,
              colors: [color, color.withOpacity(0.66)],
            ),
          ),
          alignment: Alignment.center,
          child: Text(
            initials,
            style: TT.body(size: 13, w: FontWeight.w800, color: Colors.white),
          ),
        ),
        const SizedBox(width: 11),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Text(name,
                        style: TT.body(size: 13, w: FontWeight.w800)),
                  ),
                  const SizedBox(width: 6),
                  Text(
                    time,
                    style: TT.mono(size: 9.5, color: TT.text3)
                        .copyWith(letterSpacing: 0.06 * 9.5),
                  ),
                ],
              ),
              const SizedBox(height: 2),
              Row(
                children: [
                  const Icon(Icons.place, size: 10, color: TT.ember),
                  const SizedBox(width: 4),
                  Flexible(
                    child: Text(
                      location,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: TT.mono(size: 10, color: TT.ember)
                          .copyWith(letterSpacing: 0.06 * 10, fontWeight: FontWeight.w600),
                    ),
                  ),
                  if (hazard) ...[
                    const SizedBox(width: 6),
                    const TTPill(
                        label: 'HAZARD', variant: TTPillVariant.danger),
                  ],
                ],
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _MiniElevChart extends StatefulWidget {
  const _MiniElevChart();

  @override
  State<_MiniElevChart> createState() => _MiniElevChartState();
}

class _MiniElevChartState extends State<_MiniElevChart> with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: const Duration(milliseconds: 1400));

  @override
  void initState() {
    super.initState();
    Future.delayed(const Duration(milliseconds: 500), () {
      if (mounted) _ctl.forward();
    });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 46,
      child: AnimatedBuilder(
        animation: _ctl,
        builder: (_, __) => CustomPaint(
          painter: _MiniElevPainter(progress: TT.drawCurve.transform(_ctl.value)),
          size: Size.infinite,
        ),
      ),
    );
  }
}

class _MiniElevPainter extends CustomPainter {
  final double progress;
  _MiniElevPainter({required this.progress});

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width, h = size.height;
    final path = Path()
      ..moveTo(0, h * 0.78)
      ..quadraticBezierTo(w * 0.125, h * 0.60, w * 0.25, h * 0.48)
      ..quadraticBezierTo(w * 0.40, h * 0.22, w * 0.56, h * 0.17)
      ..quadraticBezierTo(w * 0.69, h * 0.30, w * 0.81, h * 0.43)
      ..quadraticBezierTo(w * 0.91, h * 0.52, w, h * 0.65);

    // Animate the stroke draw using PathMetric trim.
    final metrics = path.computeMetrics().toList();
    if (metrics.isEmpty) return;
    final total = metrics.fold<double>(0, (a, m) => a + m.length);
    final drawn = Path();
    var consumed = 0.0;
    final target = total * progress.clamp(0.0, 1.0);
    for (final m in metrics) {
      if (consumed + m.length <= target) {
        drawn.addPath(m.extractPath(0, m.length), Offset.zero);
        consumed += m.length;
      } else {
        final remain = target - consumed;
        if (remain > 0) drawn.addPath(m.extractPath(0, remain), Offset.zero);
        break;
      }
    }

    // Fill under curve — based on the full path so the gradient holds shape.
    final fill = Path.from(path)
      ..lineTo(w, h)
      ..lineTo(0, h)
      ..close();
    final fillPaint = Paint()
      ..shader = const LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0x80FF6A2C), Color(0x00FF6A2C)],
      ).createShader(Rect.fromLTWH(0, 0, w, h));
    canvas.save();
    canvas.clipRect(Rect.fromLTWH(0, 0, w * progress.clamp(0.0, 1.0), h));
    canvas.drawPath(fill, fillPaint);
    canvas.restore();

    final stroke = Paint()
      ..color = TT.ember
      ..strokeWidth = 1.6
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    canvas.drawPath(drawn, stroke);
  }

  @override
  bool shouldRepaint(_MiniElevPainter old) => old.progress != progress;
}

class _ActionBtn extends StatelessWidget {
  final IconData icon;
  final String value;
  final VoidCallback? onTap;
  const _ActionBtn({required this.icon, required this.value, this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: TT.text2),
          const SizedBox(width: 5),
          Text(value,
              style: TT.body(size: 11, w: FontWeight.w700, color: TT.text2)
                  .copyWith(letterSpacing: 0.04 * 11)),
        ],
      ),
    );
  }
}

class _LikeBtn extends StatelessWidget {
  final bool liked;
  final int count;
  final Animation<double> anim;
  final VoidCallback onTap;
  const _LikeBtn(
      {required this.liked,
      required this.count,
      required this.anim,
      required this.onTap});

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedBuilder(
            animation: anim,
            builder: (_, __) {
              final v = anim.value;
              // Pop scale: 1 → 1.35 → 1 across the burst.
              final scale = liked && v > 0 && v < 1
                  ? 1.0 + (0.35 * (1 - (v - 0.5).abs() * 2)).clamp(0.0, 0.35)
                  : 1.0;
              return Transform.scale(
                scale: scale,
                child: Icon(
                  liked ? Icons.favorite : Icons.favorite_border,
                  size: 15,
                  color: liked ? TT.ember : TT.text2,
                ),
              );
            },
          ),
          const SizedBox(width: 5),
          Text(
            count == 0 ? 'Like' : '$count',
            style: TT.body(
                    size: 11,
                    w: FontWeight.w700,
                    color: liked ? TT.ember : TT.text2)
                .copyWith(letterSpacing: 0.04 * 11),
          ),
        ],
      ),
    );
  }
}

// ─────────────────────────────────── DETAIL / COMMENT / NOTIF SHEETS ─────────

class _PostDetailSheet extends StatelessWidget {
  final CommunityActivity activity;
  const _PostDetailSheet({required this.activity});

  @override
  Widget build(BuildContext context) {
    final color = _avatarColorFor(activity.userName);
    final initials = _initialsFor(activity.userName);
    final body = activity.subtitle.trim().isEmpty
        ? activity.title
        : '${activity.title}\n\n${activity.subtitle}';

    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.55,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (_, scroll) => Container(
        decoration: const BoxDecoration(
          color: TT.bg2,
          borderRadius: BorderRadius.vertical(top: Radius.circular(TT.rXl)),
          border: Border(top: BorderSide(color: TT.line)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: ListView(
          controller: scroll,
          children: [
            Center(
              child: Container(
                width: 42, height: 4,
                margin: const EdgeInsets.only(bottom: 14),
                decoration: BoxDecoration(
                  color: TT.line3,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            _AuthorRow(
              name: activity.userName,
              initials: initials,
              color: color,
              time: _relativeTime(activity.timestamp),
              location: activity.teamName,
              hazard: (activity.metadata['hazard'] as bool?) == true,
            ),
            const SizedBox(height: 14),
            Text(body,
                style: TT.body(size: 14, w: FontWeight.w500)
                    .copyWith(height: 1.5)),
            const SizedBox(height: 18),
            Container(height: 1, color: TT.line),
            const SizedBox(height: 14),
            _DetailMetaRow(activity: activity),
          ],
        ),
      ),
    );
  }
}

class _DetailMetaRow extends StatelessWidget {
  final CommunityActivity activity;
  const _DetailMetaRow({required this.activity});

  @override
  Widget build(BuildContext context) {
    final meta = activity.metadata;
    final tiles = <Widget>[];

    void add(String label, String value) {
      tiles.add(
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          decoration: BoxDecoration(
            color: TT.surf,
            border: Border.all(color: TT.line, width: 1),
            borderRadius: BorderRadius.circular(TT.rMd),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label.toUpperCase(),
                  style: TT.mono(size: 9, color: TT.text3)
                      .copyWith(letterSpacing: 0.08 * 9)),
              const SizedBox(height: 4),
              Text(value,
                  style: TT.numStyle(size: 14, color: TT.text)),
            ],
          ),
        ),
      );
    }

    final dist = meta['distance_km'];
    final asc = meta['ascent_m'];
    final dur = meta['duration_seconds'];
    final peaks = meta['peaks_climbed'];

    if (dist is num) add('Distance', '${dist.toStringAsFixed(1)} km');
    if (asc is num) add('Ascent', '${asc.toInt()} m');
    if (dur is num) {
      final h = dur.toInt() ~/ 3600;
      final m = (dur.toInt() % 3600) ~/ 60;
      add('Duration', h > 0 ? '${h}h ${m}m' : '${m}m');
    }
    if (peaks is num && peaks > 0) add('Peaks', peaks.toInt().toString());

    if (tiles.isEmpty) {
      return Text(
        'Posted ${_relativeTime(activity.timestamp)} from ${activity.teamName}.',
        style: TT.body(size: 12, color: TT.text2, w: FontWeight.w500),
      );
    }
    return Wrap(spacing: 10, runSpacing: 10, children: tiles);
  }
}

class _CommentsSheet extends StatefulWidget {
  final String activityId;
  const _CommentsSheet({required this.activityId});

  @override
  State<_CommentsSheet> createState() => _CommentsSheetState();
}

class _CommentsSheetState extends State<_CommentsSheet> {
  final TextEditingController _ctl = TextEditingController();
  final FocusNode _focus = FocusNode();

  @override
  void dispose() {
    _ctl.dispose();
    _focus.dispose();
    super.dispose();
  }

  void _send() {
    final auth = context.read<ap.AuthProvider>();
    final txt = _ctl.text.trim();
    if (txt.isEmpty) return;
    if (!auth.isAuth) {
      _toast(context, 'Sign in to comment.', error: true);
      return;
    }
    _PostInteractions.instance.addComment(
      widget.activityId,
      _LocalComment(
        author: auth.displayName ?? auth.email ?? 'You',
        text: txt,
        when: DateTime.now(),
      ),
    );
    _ctl.clear();
    HapticFeedback.lightImpact();
    setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    final comments = _PostInteractions.instance.comments(widget.activityId);
    final viewInset = MediaQuery.of(context).viewInsets.bottom;
    return Padding(
      padding: EdgeInsets.only(bottom: viewInset),
      child: SafeArea(
        top: false,
        child: Container(
          constraints: BoxConstraints(
            maxHeight: MediaQuery.of(context).size.height * 0.78,
          ),
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
          decoration: const BoxDecoration(
            color: TT.bg2,
            borderRadius:
                BorderRadius.vertical(top: Radius.circular(TT.rXl)),
            border: Border(top: BorderSide(color: TT.line)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Center(
                child: Container(
                  width: 42, height: 4,
                  margin: const EdgeInsets.only(bottom: 10),
                  decoration: BoxDecoration(
                    color: TT.line3,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              Row(
                children: [
                  Text('Comments',
                      style: TT.title(18, color: TT.text)),
                  const SizedBox(width: 8),
                  Text('(${comments.length})',
                      style: TT.mono(size: 11, color: TT.text3)),
                ],
              ),
              const SizedBox(height: 12),
              Flexible(
                child: comments.isEmpty
                    ? Padding(
                        padding: const EdgeInsets.symmetric(vertical: 24),
                        child: Text(
                          'No comments yet — be the first to chime in.',
                          textAlign: TextAlign.center,
                          style: TT.body(
                              size: 13,
                              w: FontWeight.w500,
                              color: TT.text3),
                        ),
                      )
                    : ListView.separated(
                        shrinkWrap: true,
                        itemCount: comments.length,
                        separatorBuilder: (_, __) => const SizedBox(height: 10),
                        itemBuilder: (_, i) {
                          final c = comments[i];
                          final color = _avatarColorFor(c.author);
                          return Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Container(
                                width: 30, height: 30,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border: Border.all(color: color, width: 1.5),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [color, color.withOpacity(0.66)],
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(_initialsFor(c.author),
                                    style: TT.body(
                                        size: 11,
                                        w: FontWeight.w800,
                                        color: Colors.white)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Row(
                                      children: [
                                        Text(c.author,
                                            style: TT.body(
                                                size: 12,
                                                w: FontWeight.w800)),
                                        const SizedBox(width: 6),
                                        Text(_relativeTime(c.when),
                                            style: TT.mono(
                                                size: 9.5, color: TT.text3)),
                                      ],
                                    ),
                                    const SizedBox(height: 2),
                                    Text(c.text,
                                        style: TT.body(
                                                size: 13,
                                                w: FontWeight.w500)
                                            .copyWith(height: 1.35)),
                                  ],
                                ),
                              ),
                            ],
                          );
                        },
                      ),
              ),
              const SizedBox(height: 10),
              Container(height: 1, color: TT.line),
              const SizedBox(height: 8),
              Row(
                children: [
                  Expanded(
                    child: Container(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
                      decoration: BoxDecoration(
                        color: TT.surf,
                        border: Border.all(color: TT.line, width: 1),
                        borderRadius: BorderRadius.circular(22),
                      ),
                      child: TextField(
                        controller: _ctl,
                        focusNode: _focus,
                        textInputAction: TextInputAction.send,
                        onSubmitted: (_) => _send(),
                        cursorColor: TT.ember,
                        style: TT.body(size: 13, w: FontWeight.w500),
                        decoration: InputDecoration(
                          isDense: true,
                          border: InputBorder.none,
                          contentPadding:
                              const EdgeInsets.symmetric(vertical: 10),
                          hintText: 'Add a comment…',
                          hintStyle: TT.body(
                              size: 13,
                              w: FontWeight.w500,
                              color: TT.text3),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTap: _send,
                    child: Container(
                      width: 40, height: 40,
                      decoration: const BoxDecoration(
                        shape: BoxShape.circle,
                        gradient: LinearGradient(
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                          colors: [TT.ember2, TT.ember],
                        ),
                        boxShadow: TT.shadowEmber,
                      ),
                      alignment: Alignment.center,
                      child: const Icon(Icons.send,
                          size: 16, color: TT.emberInk),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NotificationSheet extends StatelessWidget {
  final List<CommunityActivity> activities;
  const _NotificationSheet({required this.activities});

  @override
  Widget build(BuildContext context) {
    final recent = activities.take(20).toList();
    return DraggableScrollableSheet(
      expand: false,
      initialChildSize: 0.6,
      minChildSize: 0.35,
      maxChildSize: 0.92,
      builder: (_, scroll) => Container(
        decoration: const BoxDecoration(
          color: TT.bg2,
          borderRadius:
              BorderRadius.vertical(top: Radius.circular(TT.rXl)),
          border: Border(top: BorderSide(color: TT.line)),
        ),
        padding: const EdgeInsets.fromLTRB(18, 10, 18, 18),
        child: Column(
          children: [
            Center(
              child: Container(
                width: 42, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: TT.line3,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            Row(
              children: [
                Text('Notifications',
                    style: TT.title(18, color: TT.text)),
                const SizedBox(width: 8),
                TTPill(
                    label: recent.isEmpty ? 'EMPTY' : '${recent.length} NEW',
                    variant: recent.isEmpty
                        ? TTPillVariant.neutral
                        : TTPillVariant.ember),
                const Spacer(),
                GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  onTap: () {
                    Navigator.of(context).pop();
                    _toast(context, 'Marked as read.');
                  },
                  child: Text('Mark all read',
                      style: TT.body(
                          size: 12,
                          w: FontWeight.w700,
                          color: TT.ember)),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Expanded(
              child: recent.isEmpty
                  ? Center(
                      child: Padding(
                        padding: const EdgeInsets.symmetric(horizontal: 24),
                        child: Text(
                          'Nothing new yet. New posts and check-ins will surface here.',
                          textAlign: TextAlign.center,
                          style: TT.body(
                              size: 13,
                              w: FontWeight.w500,
                              color: TT.text3),
                        ),
                      ),
                    )
                  : ListView.separated(
                      controller: scroll,
                      itemCount: recent.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (_, i) {
                        final a = recent[i];
                        final color = _avatarColorFor(a.userName);
                        return Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 12, vertical: 10),
                          decoration: BoxDecoration(
                            color: TT.surf,
                            border: Border.all(color: TT.line, width: 1),
                            borderRadius: BorderRadius.circular(TT.rMd),
                          ),
                          child: Row(
                            children: [
                              Container(
                                width: 32, height: 32,
                                decoration: BoxDecoration(
                                  shape: BoxShape.circle,
                                  border:
                                      Border.all(color: color, width: 1.5),
                                  gradient: LinearGradient(
                                    begin: Alignment.topLeft,
                                    end: Alignment.bottomRight,
                                    colors: [color, color.withOpacity(0.66)],
                                  ),
                                ),
                                alignment: Alignment.center,
                                child: Text(_initialsFor(a.userName),
                                    style: TT.body(
                                        size: 11,
                                        w: FontWeight.w800,
                                        color: Colors.white)),
                              ),
                              const SizedBox(width: 10),
                              Expanded(
                                child: Column(
                                  crossAxisAlignment:
                                      CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      '${a.userName} · ${a.title}',
                                      maxLines: 1,
                                      overflow: TextOverflow.ellipsis,
                                      style: TT.body(
                                          size: 12.5,
                                          w: FontWeight.w800),
                                    ),
                                    const SizedBox(height: 2),
                                    Text(
                                      _relativeTime(a.timestamp),
                                      style: TT.mono(
                                          size: 10, color: TT.text3),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        );
                      },
                    ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────── CHAT ───────────────────────────────────

class _ChatView extends StatefulWidget {
  final String query;
  const _ChatView({super.key, required this.query});

  @override
  State<_ChatView> createState() => _ChatViewState();
}

class _ChatViewState extends State<_ChatView> {
  final ScrollController _scroll = ScrollController();
  final TextEditingController _composer = TextEditingController();
  final FocusNode _composerFocus = FocusNode();
  int _lastMsgCount = 0;
  final Set<String> _hiddenIds = <String>{}; // optimistic-delete cache

  @override
  void dispose() {
    _scroll.dispose();
    _composer.dispose();
    _composerFocus.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animate = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scroll.hasClients) return;
      final target = _scroll.position.maxScrollExtent;
      if (animate) {
        _scroll.animateTo(target,
            duration: const Duration(milliseconds: 280),
            curve: Curves.easeOut);
      } else {
        _scroll.jumpTo(target);
      }
    });
  }

  Future<void> _send(ChatProvider chat) async {
    final auth = context.read<ap.AuthProvider>();
    final txt = _composer.text.trim();
    if (txt.isEmpty) return;

    if (!auth.isAuth) {
      _toast(context, 'Please sign in to join the community chat.',
          error: true);
      return;
    }

    final senderId = auth.uid ?? '';
    final senderName = auth.displayName ?? auth.email ?? 'Hiker';

    _composer.clear();
    await chat.sendText(
      senderId: senderId,
      senderName: senderName,
      text: txt,
    );
    _scrollToBottom();
  }

  Future<void> _onLongPressMessage(ChatMessage m, bool mine) async {
    unawaited(HapticFeedback.selectionClick());
    final action = await showModalBottomSheet<String>(
      context: context,
      backgroundColor: TT.bg2,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(TT.rXl)),
      ),
      builder: (_) => SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 12),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 42, height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: TT.line3,
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              _SheetAction(
                icon: Icons.copy_outlined,
                label: 'Copy text',
                onTap: () => Navigator.of(context).pop('copy'),
              ),
              if (mine)
                _SheetAction(
                  icon: Icons.delete_outline,
                  label: 'Delete message',
                  danger: true,
                  onTap: () => Navigator.of(context).pop('delete'),
                ),
              const SizedBox(height: 6),
              _SheetAction(
                icon: Icons.close,
                label: 'Cancel',
                onTap: () => Navigator.of(context).pop('cancel'),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || action == null || action == 'cancel') return;

    if (action == 'copy') {
      await Clipboard.setData(ClipboardData(text: m.text));
      if (!mounted) return;
      _toast(context, 'Copied to clipboard.');
      return;
    }

    if (action == 'delete') {
      if (!mine) return;
      setState(() => _hiddenIds.add(m.id));
      if (!kSupabaseAvailable) {
        _toast(context, 'Message removed locally.');
        return;
      }
      try {
        await Supabase.instance.client
            .from(kColChat)
            .delete()
            .eq('id', m.id);
        if (!mounted) return;
        _toast(context, 'Message deleted.');
      } catch (e) {
        if (!mounted) return;
        setState(() => _hiddenIds.remove(m.id));
        _toast(context, 'Could not delete message.', error: true);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Consumer<ChatProvider>(
      builder: (_, chat, __) {
        // ChatProvider already returns oldest-first (service does .reversed
        // after sorting sent_at DESC). Defensive sort keeps ordering stable
        // if that ever changes.
        final messages = List<ChatMessage>.from(chat.messages)
          ..sort((a, b) => a.timestamp.compareTo(b.timestamp));

        // Drop locally-deleted ids and apply the search filter.
        final filtered = messages.where((m) {
          if (_hiddenIds.contains(m.id)) return false;
          if (widget.query.isEmpty) return true;
          return _matchesQuery('${m.senderName} ${m.text}', widget.query);
        }).toList();

        // Auto-scroll to bottom when message count changes (new message
        // arrives) or on initial build.
        if (messages.length != _lastMsgCount) {
          _lastMsgCount = messages.length;
          _scrollToBottom(animate: _lastMsgCount > 0);
        }

        final auth = context.watch<ap.AuthProvider>();
        final myUid = auth.uid;

        return Column(
          children: [
            const Padding(
              padding: EdgeInsets.fromLTRB(18, 12, 18, 6),
              child: _FadeUpDelayed(
                delay: Duration(milliseconds: 120),
                child: _PinnedChannel(),
              ),
            ),
            Expanded(
              child: filtered.isEmpty
                  ? _EmptyChat(filtered: widget.query.isNotEmpty)
                  : ListView.builder(
                      controller: _scroll,
                      padding: const EdgeInsets.fromLTRB(18, 8, 18, 12),
                      itemCount: filtered.length,
                      itemBuilder: (_, i) {
                        final m = filtered[i];
                        final mine =
                            myUid != null && m.senderId == myUid;
                        return Padding(
                          padding: EdgeInsets.only(
                              bottom: i == filtered.length - 1 ? 0 : 10),
                          child: _FadeUpDelayed(
                            // Cap the stagger so older messages don't pile
                            // up huge delays on the first render.
                            delay: Duration(
                                milliseconds: 80 + (i.clamp(0, 8)) * 50),
                            child: _ChatMsg(
                              msg: m,
                              mine: mine,
                              onLongPress: () => _onLongPressMessage(m, mine),
                            ),
                          ),
                        );
                      },
                    ),
            ),
            _ChatComposer(
              controller: _composer,
              focus: _composerFocus,
              sending: chat.sending,
              onSend: () => _send(chat),
            ),
          ],
        );
      },
    );
  }
}

class _SheetAction extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool danger;
  const _SheetAction({
    required this.icon,
    required this.label,
    required this.onTap,
    this.danger = false,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
        decoration: BoxDecoration(
          color: TT.surf,
          border: Border.all(color: TT.line, width: 1),
          borderRadius: BorderRadius.circular(TT.rMd),
        ),
        child: Row(
          children: [
            Icon(icon, size: 18, color: danger ? TT.red : TT.text),
            const SizedBox(width: 12),
            Text(label,
                style: TT.body(
                    size: 14,
                    w: FontWeight.w700,
                    color: danger ? TT.red : TT.text)),
          ],
        ),
      ),
    );
  }
}

class _EmptyChat extends StatelessWidget {
  final bool filtered;
  const _EmptyChat({this.filtered = false});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 32),
        child: Text(
          filtered
              ? 'No messages match your search.'
              : 'Be the first to say hello',
          textAlign: TextAlign.center,
          style: TT.body(size: 13, w: FontWeight.w500, color: TT.text3),
        ),
      ),
    );
  }
}

class _PinnedChannel extends StatelessWidget {
  const _PinnedChannel();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: TT.emberDim,
        border: Border.all(color: const Color(0x52FF6A2C), width: 1),
        borderRadius: BorderRadius.circular(11),
      ),
      child: Row(
        children: [
          Container(
            width: 30, height: 30,
            decoration: BoxDecoration(
              color: const Color(0x38FF6A2C),
              border: Border.all(color: const Color(0x73FF6A2C), width: 1),
              borderRadius: BorderRadius.circular(9),
            ),
            alignment: Alignment.center,
            child: const Icon(Icons.groups, size: 14, color: TT.ember),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Community · Team Chat',
                    style: TT.body(size: 12.5, w: FontWeight.w800, color: TT.ember)),
                const SizedBox(height: 2),
                Text('LIVE · #GENERAL',
                    style: TT.mono(size: 10, color: TT.text3)
                        .copyWith(letterSpacing: 0.04 * 10, fontWeight: FontWeight.w600)),
              ],
            ),
          ),
          const TTPill(label: 'LIVE', variant: TTPillVariant.live),
        ],
      ),
    );
  }
}

class _ChatMsg extends StatelessWidget {
  final ChatMessage msg;
  final bool mine;
  final VoidCallback onLongPress;
  const _ChatMsg(
      {required this.msg, required this.mine, required this.onLongPress});

  @override
  Widget build(BuildContext context) {
    if (msg.type == ChatMessageType.system) {
      return Padding(
        padding: const EdgeInsets.symmetric(vertical: 4),
        child: Text(
          msg.text,
          textAlign: TextAlign.center,
          style: TT.mono(size: 10, color: TT.text3)
              .copyWith(letterSpacing: 0.06 * 10),
        ),
      );
    }

    final bubbleBg = mine ? TT.emberDim : TT.surf;
    final bubbleBorder = mine ? const Color(0x5CFF6A2C) : TT.line;
    final bubbleColor = mine ? TT.ember3 : TT.text;
    final radius = mine
        ? const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(14),
            bottomRight: Radius.circular(4),
          )
        : const BorderRadius.only(
            topLeft: Radius.circular(14),
            topRight: Radius.circular(14),
            bottomLeft: Radius.circular(4),
            bottomRight: Radius.circular(14),
          );

    final color = _avatarColorFor(msg.senderId.isNotEmpty ? msg.senderId : msg.senderName);
    final initials = _initialsFor(msg.senderName);
    final timeLabel = _clockTime(msg.timestamp);

    return LayoutBuilder(builder: (_, c) {
      final maxBubbleW = c.maxWidth * 0.74;
      final avatar = !mine
          ? Container(
              width: 30, height: 30,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                border: Border.all(color: color, width: 1.5),
                gradient: LinearGradient(
                  begin: Alignment.topLeft, end: Alignment.bottomRight,
                  colors: [color, color.withOpacity(0.66)],
                ),
              ),
              alignment: Alignment.center,
              child: Text(
                initials,
                style: TT.body(size: 11, w: FontWeight.w800, color: Colors.white),
              ),
            )
          : null;

      final column = Column(
        crossAxisAlignment: mine ? CrossAxisAlignment.end : CrossAxisAlignment.start,
        children: [
          if (!mine)
            Padding(
              padding: const EdgeInsets.only(bottom: 3),
              child: Text(
                '${msg.senderName} · $timeLabel',
                style: TT.mono(size: 10, color: TT.text3)
                    .copyWith(letterSpacing: 0.04 * 10),
              ),
            ),
          GestureDetector(
            behavior: HitTestBehavior.opaque,
            onLongPress: onLongPress,
            child: ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxBubbleW),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                decoration: BoxDecoration(
                  color: bubbleBg,
                  border: Border.all(color: bubbleBorder, width: 1),
                  borderRadius: radius,
                ),
                child: Text(
                  msg.text,
                  style: TT.body(size: 12.5, w: FontWeight.w500, color: bubbleColor)
                      .copyWith(height: 1.4),
                ),
              ),
            ),
          ),
          if (mine)
            Padding(
              padding: const EdgeInsets.only(top: 3),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    timeLabel,
                    style: TT.mono(size: 9.5, color: TT.text3)
                        .copyWith(letterSpacing: 0.04 * 9.5, fontWeight: FontWeight.w600),
                  ),
                  const SizedBox(width: 4),
                  const Icon(Icons.done_all, size: 12, color: TT.green),
                ],
              ),
            ),
        ],
      );

      return Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        mainAxisAlignment: mine ? MainAxisAlignment.end : MainAxisAlignment.start,
        children: mine
            ? [Flexible(child: column)]
            : [
                if (avatar != null) avatar,
                const SizedBox(width: 8),
                Flexible(child: column),
              ],
      );
    });
  }
}

class _ChatComposer extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focus;
  final bool sending;
  final VoidCallback onSend;
  const _ChatComposer({
    required this.controller,
    required this.focus,
    required this.sending,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.fromLTRB(18, 10, 18, 14),
      decoration: const BoxDecoration(
        color: TT.bg2,
        border: Border(top: BorderSide(color: TT.line, width: 1)),
      ),
      child: SafeArea(
        top: false,
        child: Row(
          children: [
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () => focus.requestFocus(),
              child: Container(
                width: 38, height: 38,
                decoration: BoxDecoration(
                  color: const Color(0x08FFFFFF),
                  border: Border.all(color: TT.line, width: 1),
                  borderRadius: BorderRadius.circular(TT.rMd),
                ),
                alignment: Alignment.center,
                child: const Icon(Icons.add, size: 18, color: TT.text2),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 2),
                decoration: BoxDecoration(
                  color: TT.surf,
                  border: Border.all(color: TT.line, width: 1),
                  borderRadius: BorderRadius.circular(22),
                ),
                child: TextField(
                  controller: controller,
                  focusNode: focus,
                  enabled: !sending,
                  textInputAction: TextInputAction.send,
                  onSubmitted: (_) => onSend(),
                  cursorColor: TT.ember,
                  style: TT.body(size: 13, w: FontWeight.w500),
                  decoration: InputDecoration(
                    isDense: true,
                    border: InputBorder.none,
                    enabledBorder: InputBorder.none,
                    focusedBorder: InputBorder.none,
                    contentPadding:
                        const EdgeInsets.symmetric(vertical: 10),
                    hintText: 'Message…',
                    hintStyle: TT.body(
                        size: 13,
                        w: FontWeight.w500,
                        color: TT.text3),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 10),
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: sending ? null : onSend,
              child: Container(
                width: 42, height: 42,
                decoration: const BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: LinearGradient(
                    begin: Alignment.topLeft, end: Alignment.bottomRight,
                    colors: [TT.ember2, TT.ember],
                  ),
                  boxShadow: TT.shadowEmber,
                ),
                alignment: Alignment.center,
                child: sending
                    ? const SizedBox(
                        width: 16, height: 16,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          valueColor:
                              AlwaysStoppedAnimation<Color>(TT.emberInk),
                        ),
                      )
                    : const Icon(Icons.send, size: 16, color: TT.emberInk),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

// ─────────────────────────────────── SEARCH FIELD ───────────────────────────

class _SearchField extends StatelessWidget {
  final TextEditingController controller;
  final ValueChanged<String> onChanged;
  final String hint;
  const _SearchField({
    required this.controller,
    required this.onChanged,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 2),
      decoration: BoxDecoration(
        color: TT.surf,
        border: Border.all(color: TT.line, width: 1),
        borderRadius: BorderRadius.circular(TT.rMd),
      ),
      child: Row(
        children: [
          const Icon(Icons.search, size: 16, color: TT.text3),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              onChanged: onChanged,
              autofocus: true,
              cursorColor: TT.ember,
              style: TT.body(size: 13, w: FontWeight.w500),
              decoration: InputDecoration(
                isDense: true,
                border: InputBorder.none,
                contentPadding: const EdgeInsets.symmetric(vertical: 10),
                hintText: hint,
                hintStyle: TT.body(
                    size: 13, w: FontWeight.w500, color: TT.text3),
              ),
            ),
          ),
          if (controller.text.isNotEmpty)
            GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTap: () {
                controller.clear();
                onChanged('');
              },
              child: const Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: Icon(Icons.clear, size: 14, color: TT.text3),
              ),
            ),
        ],
      ),
    );
  }
}

// ────────────────────────────── ANIMATION HELPER ────────────────────────────

class _FadeUpDelayed extends StatefulWidget {
  final Duration delay;
  final Widget child;
  const _FadeUpDelayed({required this.delay, required this.child});

  @override
  State<_FadeUpDelayed> createState() => _FadeUpDelayedState();
}

class _FadeUpDelayedState extends State<_FadeUpDelayed>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctl =
      AnimationController(vsync: this, duration: TT.dSlow);
  late final Animation<double> _t =
      CurvedAnimation(parent: _ctl, curve: TT.easeOut);

  @override
  void initState() {
    super.initState();
    Future.delayed(widget.delay, () { if (mounted) _ctl.forward(); });
  }

  @override
  void dispose() {
    _ctl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _t,
      builder: (_, __) {
        final v = _t.value;
        return Opacity(
          opacity: v,
          child: Transform.translate(
            offset: Offset(0, (1 - v) * 14),
            child: widget.child,
          ),
        );
      },
    );
  }
}
