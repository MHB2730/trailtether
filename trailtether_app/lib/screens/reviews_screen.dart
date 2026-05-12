import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:provider/provider.dart';
import '../core/constants.dart';
import '../models/review.dart';
import '../models/trail.dart';
import '../providers/review_provider.dart';
import '../widgets/review/review_card.dart';
import '../widgets/review/review_summary_bar.dart';
import '../widgets/review/star_rating_input.dart';

class ReviewsScreen extends StatefulWidget {
  final Trail trail;
  const ReviewsScreen({super.key, required this.trail});

  @override
  State<ReviewsScreen> createState() => _ReviewsScreenState();
}

class _ReviewsScreenState extends State<ReviewsScreen> {
  int _rating = 0;
  String _condition = '';
  final _textCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    context.read<ReviewProvider>().listenTo(widget.trail.id);
  }

  @override
  void dispose() {
    _textCtrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: kColorBg,
      appBar: AppBar(
        title: Text(widget.trail.name),
        backgroundColor: kColorBg,
      ),
      body: Column(
        children: [
          // Review list
          Expanded(
            child: Consumer<ReviewProvider>(
              builder: (_, prov, __) {
                if (prov.reviews.isEmpty) {
                  return Center(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(Icons.rate_review_outlined,
                            color: kColorCream.withOpacity(0.2), size: 48),
                        const SizedBox(height: 12),
                        Text(
                          'No reviews yet.\nBe the first to review this trail!',
                          textAlign: TextAlign.center,
                          style: GoogleFonts.outfit(
                            color: kColorCream.withOpacity(0.4),
                            fontSize: 14,
                          ),
                        ),
                      ],
                    ),
                  );
                }
                return ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    ReviewSummaryBar(summary: prov.summary),
                    const SizedBox(height: 16),
                    ...prov.reviews.map((r) => _ReviewRow(review: r)),
                  ],
                );
              },
            ),
          ),

          // Submit form
          _SubmitForm(
            rating: _rating,
            condition: _condition,
            textCtrl: _textCtrl,
            onRating: (v) => setState(() => _rating = v),
            onCondition: (v) => setState(() => _condition = v),
            onSubmit: _submit,
          ),
        ],
      ),
    );
  }

  Future<void> _submit() async {
    if (_rating == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a star rating')),
      );
      return;
    }
    if (_textCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please write a short review')),
      );
      return;
    }

    final ok = await context.read<ReviewProvider>().submit(
          trailId: widget.trail.id,
          trailName: widget.trail.name,
          rating: _rating,
          text: _textCtrl.text.trim(),
          condition: _condition,
        );

    if (ok && mounted) {
      setState(() {
        _rating = 0;
        _condition = '';
      });
      _textCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Review submitted — thanks!')),
      );
    }
  }
}

// ── Review row with owner edit/delete ─────────────────────────────────────
class _ReviewRow extends StatelessWidget {
  final Review review;
  const _ReviewRow({required this.review});

  @override
  Widget build(BuildContext context) {
    final prov = context.read<ReviewProvider>();
    final isOwner = prov.isOwner(review);
    return Stack(
      children: [
        ReviewCard(review: review),
        if (isOwner)
          Positioned(
            top: 4,
            right: 4,
            child: PopupMenuButton<String>(
              icon: Icon(Icons.more_vert,
                  color: kColorCream.withOpacity(0.35), size: 16),
              color: const Color(0xFF1A1A1A),
              itemBuilder: (_) => [
                PopupMenuItem(
                  value: 'edit',
                  child: Row(children: [
                    const Icon(Icons.edit_outlined,
                        size: 16, color: kColorOrange),
                    const SizedBox(width: 8),
                    Text('Edit', style: GoogleFonts.outfit(color: kColorCream)),
                  ]),
                ),
                PopupMenuItem(
                  value: 'delete',
                  child: Row(children: [
                    const Icon(Icons.delete_outline,
                        size: 16, color: Color(0xFFE53935)),
                    const SizedBox(width: 8),
                    Text('Delete',
                        style:
                            GoogleFonts.outfit(color: const Color(0xFFE53935))),
                  ]),
                ),
              ],
              onSelected: (action) async {
                if (action == 'edit') {
                  _showEditDialog(context, review, prov);
                } else if (action == 'delete') {
                  final confirmed = await showDialog<bool>(
                    context: context,
                    builder: (_) => AlertDialog(
                      backgroundColor: const Color(0xFF1A1A1A),
                      title: Text('Delete review?',
                          style: GoogleFonts.outfit(
                              color: kColorCream, fontWeight: FontWeight.w700)),
                      content: Text('This cannot be undone.',
                          style: GoogleFonts.outfit(
                              color: kColorCream.withOpacity(0.6),
                              fontSize: 13)),
                      actions: [
                        TextButton(
                            onPressed: () => Navigator.pop(context, false),
                            child: Text('Cancel',
                                style: GoogleFonts.outfit(
                                    color: kColorCream.withOpacity(0.5)))),
                        TextButton(
                            onPressed: () => Navigator.pop(context, true),
                            child: Text('Delete',
                                style: GoogleFonts.outfit(
                                    color: const Color(0xFFE53935),
                                    fontWeight: FontWeight.w700))),
                      ],
                    ),
                  );
                  if (confirmed == true && context.mounted) {
                    await prov.deleteReview(review.id);
                  }
                }
              },
            ),
          ),
      ],
    );
  }

  void _showEditDialog(
      BuildContext context, Review original, ReviewProvider prov) {
    int rating = original.rating;
    String condition = original.condition;
    final textCtrl = TextEditingController(text: original.text);

    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setState) => Padding(
          padding: EdgeInsets.fromLTRB(
              16, 16, 16, MediaQuery.of(ctx).viewInsets.bottom + 24),
          child: Container(
            padding: const EdgeInsets.all(20),
            decoration: const BoxDecoration(
              color: Color(0xFF1A1A1A),
              borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Edit Review',
                    style: GoogleFonts.outfit(
                        color: kColorCream,
                        fontSize: 16,
                        fontWeight: FontWeight.w700)),
                const SizedBox(height: 12),
                StarRatingInput(
                    value: rating,
                    onChanged: (v) => setState(() => rating = v)),
                const SizedBox(height: 12),
                TextField(
                  controller: textCtrl,
                  maxLength: 500,
                  maxLines: 3,
                  style: GoogleFonts.outfit(color: kColorCream, fontSize: 13),
                  decoration: InputDecoration(
                    hintText: 'Update your review…',
                    hintStyle: GoogleFonts.outfit(
                        color: kColorCream.withOpacity(0.3), fontSize: 13),
                    counterStyle: const TextStyle(color: Colors.white30),
                    filled: true,
                    fillColor: Colors.white.withOpacity(0.05),
                    border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: kColorBorder)),
                    enabledBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide: const BorderSide(color: kColorBorder)),
                    focusedBorder: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(8),
                        borderSide:
                            const BorderSide(color: kColorOrange, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 12),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () async {
                      final updated = original.copyWith(
                          rating: rating,
                          text: textCtrl.text.trim(),
                          condition: condition);
                      Navigator.pop(ctx);
                      await prov.updateReview(updated);
                    },
                    child: Text('Save Changes',
                        style: GoogleFonts.outfit(fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _SubmitForm extends StatelessWidget {
  static const _conditions = ['good', 'fair', 'poor'];

  final int rating;
  final String condition;
  final TextEditingController textCtrl;
  final ValueChanged<int> onRating;
  final ValueChanged<String> onCondition;
  final VoidCallback onSubmit;

  const _SubmitForm({
    required this.rating,
    required this.condition,
    required this.textCtrl,
    required this.onRating,
    required this.onCondition,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: EdgeInsets.fromLTRB(
          16, 12, 16, MediaQuery.of(context).viewInsets.bottom + 16),
      decoration: const BoxDecoration(
        color: kColorPanel,
        border: Border(top: BorderSide(color: kColorBorder)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Leave a Review',
            style: GoogleFonts.outfit(
              color: kColorCream,
              fontSize: 14,
              fontWeight: FontWeight.w600,
            ),
          ),
          const SizedBox(height: 8),
          StarRatingInput(value: rating, onChanged: onRating),
          const SizedBox(height: 10),

          // Trail condition chips
          Row(
            children: [
              Text('Condition: ',
                  style: GoogleFonts.outfit(
                      color: kColorCream.withOpacity(0.5), fontSize: 12)),
              ..._conditions.map((c) {
                final sel = condition == c;
                return Padding(
                  padding: const EdgeInsets.only(right: 6),
                  child: GestureDetector(
                    onTap: () => onCondition(sel ? '' : c),
                    child: Chip(
                      label: Text(
                        c[0].toUpperCase() + c.substring(1),
                        style: GoogleFonts.outfit(
                            fontSize: 11,
                            color: sel
                                ? Colors.white
                                : kColorCream.withOpacity(0.6)),
                      ),
                      backgroundColor: sel
                          ? (c == 'good'
                              ? Colors.green
                              : c == 'fair'
                                  ? Colors.amber
                                  : Colors.red)
                          : Colors.transparent,
                      side: const BorderSide(color: kColorBorder),
                      padding: const EdgeInsets.symmetric(horizontal: 4),
                      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                  ),
                );
              }),
            ],
          ),
          const SizedBox(height: 10),

          TextField(
            controller: textCtrl,
            maxLength: 500,
            maxLines: 3,
            style: const TextStyle(color: kColorCream, fontSize: 13),
            decoration: const InputDecoration(
              hintText: 'Describe the trail conditions, highlights…',
              counterStyle: TextStyle(color: Colors.white30),
            ),
          ),
          const SizedBox(height: 10),

          Consumer<ReviewProvider>(
            builder: (_, prov, __) => SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                onPressed: prov.submitting ? null : onSubmit,
                child: prov.submitting
                    ? const SizedBox(
                        width: 20,
                        height: 20,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Submit Review'),
              ),
            ),
          ),
        ],
      ),
    );
  }
}
