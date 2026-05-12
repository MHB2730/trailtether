import 'package:supabase_flutter/supabase_flutter.dart';
import '../models/review.dart';
import '../core/constants.dart';

SupabaseClient get _db => Supabase.instance.client;

class ReviewService {
  /// Real-time stream of reviews for a trail, newest first.
  static Stream<List<Review>> reviewsForTrail(String trailId) {
    return _db
        .from(kColReviews)
        .stream(primaryKey: ['id'])
        .eq('trail_id', trailId)
        .order('created_at', ascending: false)
        .map((rows) => rows.map(Review.fromMap).toList());
  }

  /// Add a new review.
  static Future<void> addReview(Review review) async {
    assert(review.rating >= 1 && review.rating <= 5);
    assert(review.text.isNotEmpty && review.text.length <= 500);
    await _db.from(kColReviews).insert(review.toInsertMap());
  }

  /// Update rating / text / condition of an existing review (owner only).
  static Future<void> updateReview(Review review) async {
    await _db
        .from(kColReviews)
        .update(review.toUpdateMap())
        .eq('id', review.id);
  }

  /// Delete a review (owner or admin).
  static Future<void> deleteReview(String reviewId) async {
    await _db.from(kColReviews).delete().eq('id', reviewId);
  }

  /// One-shot fetch of summary (avg rating + count) for a trail.
  static Future<ReviewSummary> summaryForTrail(String trailId) async {
    final rows =
        await _db.from(kColReviews).select('rating').eq('trail_id', trailId);
    final reviews = (rows as List<dynamic>)
        .map((r) => Review.fromMap(r as Map<String, dynamic>))
        .toList();
    return ReviewSummary.fromList(reviews);
  }
}
