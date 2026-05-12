import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../core/constants.dart';
import '../../providers/chat_provider.dart';

class AdminCommunityTab extends StatefulWidget {
  const AdminCommunityTab({super.key});

  @override
  State<AdminCommunityTab> createState() => _AdminCommunityTabState();
}

class _AdminCommunityTabState extends State<AdminCommunityTab> {
  final _supabase = Supabase.instance.client;
  List<Map<String, dynamic>> _reviews = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _fetchCommunityData();
  }

  Future<void> _fetchCommunityData() async {
    setState(() => _loading = true);
    try {
      final response = await _supabase
          .from(kColReviews)
          .select('*, profiles(username)')
          .order('created_at', ascending: false);

      setState(() {
        _reviews = List<Map<String, dynamic>>.from(response);
        _loading = false;
      });
    } catch (e) {
      debugPrint('Error fetching community data: $e');
      setState(() => _loading = false);
    }
  }

  Future<void> _deleteReview(String id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: kColorBg,
        title:
            const Text('Delete Review?', style: TextStyle(color: Colors.white)),
        content: const Text(
            'This will remove the review from the community page.',
            style: TextStyle(color: Colors.white70)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          TextButton(
            onPressed: () => Navigator.pop(context, true),
            child:
                const Text('Delete', style: TextStyle(color: Colors.redAccent)),
          ),
        ],
      ),
    );

    if (confirm == true) {
      setState(() => _loading = true);
      try {
        await _supabase.from(kColReviews).delete().eq('id', id);
        await _fetchCommunityData();
      } catch (e) {
        debugPrint('Error deleting review: $e');
      } finally {
        setState(() => _loading = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(32.0),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Community Moderation',
                    style: GoogleFonts.outfit(
                      color: kColorCream,
                      fontSize: 32,
                      fontWeight: FontWeight.w900,
                    ),
                  ),
                  Text(
                    'Manage reviews, forum posts, and user interactions.',
                    style: GoogleFonts.outfit(
                      color: kColorCream.withOpacity(0.5),
                      fontSize: 16,
                    ),
                  ),
                ],
              ),
              IconButton(
                onPressed: _fetchCommunityData,
                icon: const Icon(Icons.refresh, color: kColorOrange),
              ),
            ],
          ),
          const SizedBox(height: 32),
          Expanded(
            child: _loading
                ? const Center(
                    child: CircularProgressIndicator(color: kColorOrange))
                : Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Expanded(child: _buildReviewQueue()),
                      const SizedBox(width: 24),
                      Expanded(child: _buildChatMonitoring()),
                    ],
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildReviewQueue() {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: kColorGlass,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: kColorBorder),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.rate_review, color: kColorOrange, size: 20),
              const SizedBox(width: 12),
              const Text('Recent Reviews',
                  style: TextStyle(
                      color: Colors.white,
                      fontSize: 18,
                      fontWeight: FontWeight.bold)),
              const Spacer(),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                decoration: BoxDecoration(
                    color: kColorOrange.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(12)),
                child: Text('${_reviews.length}',
                    style: const TextStyle(
                        color: kColorOrange,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 24),
          Expanded(
            child: _reviews.isEmpty
                ? Center(
                    child: Text('No reviews found.',
                        style: TextStyle(color: Colors.white.withOpacity(0.2))))
                : ListView.separated(
                    itemCount: _reviews.length,
                    separatorBuilder: (_, __) =>
                        const Divider(color: kColorBorder),
                    itemBuilder: (context, index) {
                      final review = _reviews[index];
                      return ListTile(
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          backgroundColor: kColorOrange.withOpacity(0.1),
                          radius: 16,
                          child: Text(review['rating']?.toString() ?? '?',
                              style: const TextStyle(
                                  color: kColorOrange,
                                  fontSize: 12,
                                  fontWeight: FontWeight.bold)),
                        ),
                        title: Text(
                          'Review by ${review['profiles']?['username'] ?? 'Anonymous'}',
                          style: const TextStyle(
                              color: Colors.white,
                              fontSize: 14,
                              fontWeight: FontWeight.bold),
                        ),
                        subtitle: Text(
                          review['comment'] ?? 'No comment.',
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(
                              color: Colors.white.withOpacity(0.5),
                              fontSize: 12),
                        ),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            IconButton(
                              icon: const Icon(Icons.delete_outline,
                                  color: Colors.redAccent, size: 18),
                              onPressed: () => _deleteReview(review['id']),
                            ),
                          ],
                        ),
                      );
                    },
                  ),
          ),
        ],
      ),
    );
  }

  Widget _buildChatMonitoring() {
    return Consumer<ChatProvider>(
      builder: (context, chat, _) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: kColorGlass,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: kColorBorder),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const Icon(Icons.forum, color: kColorCyan, size: 20),
                const SizedBox(width: 12),
                const Text('Live Chat Feed',
                    style: TextStyle(
                        color: Colors.white,
                        fontSize: 18,
                        fontWeight: FontWeight.bold)),
                const Spacer(),
                _buildPulseIndicator(),
              ],
            ),
            const SizedBox(height: 24),
            Expanded(
              child: chat.messages.isEmpty
                  ? Center(
                      child: Text('No messages yet.',
                          style:
                              TextStyle(color: Colors.white.withOpacity(0.2))))
                  : ListView.separated(
                      itemCount: chat.messages.length,
                      separatorBuilder: (_, __) =>
                          const Divider(color: kColorBorder, height: 1),
                      itemBuilder: (context, index) {
                        final msg = chat.messages[chat.messages.length -
                            1 -
                            index]; // Reverse for feed
                        return ListTile(
                          contentPadding: EdgeInsets.zero,
                          title: Row(
                            children: [
                              Text(msg.senderName,
                                  style: const TextStyle(
                                      color: kColorCyan,
                                      fontSize: 12,
                                      fontWeight: FontWeight.bold)),
                              const Spacer(),
                              Text(DateFormat('HH:mm').format(msg.timestamp),
                                  style: TextStyle(
                                      color: Colors.white.withOpacity(0.2),
                                      fontSize: 10)),
                            ],
                          ),
                          subtitle: Text(msg.text,
                              style: const TextStyle(
                                  color: Colors.white70, fontSize: 13)),
                          trailing: IconButton(
                            icon: const Icon(Icons.delete_outline,
                                size: 16, color: Colors.white54),
                            tooltip: 'Delete message',
                            onPressed: () async {
                              final confirm = await showDialog<bool>(
                                context: context,
                                builder: (ctx) => AlertDialog(
                                  title: const Text('Delete message?'),
                                  content: Text(
                                      'This will remove the message from all clients. Action cannot be undone.\n\n"${msg.text}"'),
                                  actions: [
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, false),
                                        child: const Text('Cancel')),
                                    TextButton(
                                        onPressed: () =>
                                            Navigator.pop(ctx, true),
                                        child: const Text('Delete',
                                            style: TextStyle(
                                                color: Colors.redAccent))),
                                  ],
                                ),
                              );
                              if (confirm != true) return;
                              try {
                                await Supabase.instance.client
                                    .from('chat_messages')
                                    .delete()
                                    .eq('id', msg.id);
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      const SnackBar(
                                          content: Text('Message deleted.')));
                                }
                              } catch (e) {
                                if (context.mounted) {
                                  ScaffoldMessenger.of(context).showSnackBar(
                                      SnackBar(
                                          content:
                                              Text('Delete failed: $e')));
                                }
                              }
                            },
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

  Widget _buildPulseIndicator() {
    return Consumer<ChatProvider>(
      builder: (context, chat, _) => Container(
        width: 8,
        height: 8,
        decoration: BoxDecoration(
          color: chat.sending ? Colors.orangeAccent : kColorCyan,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
                color: chat.sending ? Colors.orangeAccent : kColorCyan,
                blurRadius: 4,
                spreadRadius: 1)
          ],
        ),
      ),
    );
  }
}
