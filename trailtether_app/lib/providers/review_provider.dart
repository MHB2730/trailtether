import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../core/runtime_config.dart';
import '../models/review.dart';
import '../services/review_service.dart';

class ReviewProvider extends ChangeNotifier {
  List<Review> _reviews = [];
  bool _submitting = false;
  String? _error;
  String? _currentTrailId;
  StreamSubscription<List<Review>>? _sub;

  List<Review> get reviews => _reviews;
  bool get submitting => _submitting;
  String? get error => _error;

  /// The current user ID (null if not signed in or Supabase unavailable).
  String? get _uid =>
      kSupabaseAvailable ? Supabase.instance.client.auth.currentUser?.id : null;

  void listenTo(String trailId) {
    if (_currentTrailId == trailId) return;
    _currentTrailId = trailId;
    _sub?.cancel();
    _sub = null;
    _reviews = [];
    if (!kSupabaseAvailable) return;
    _sub = ReviewService.reviewsForTrail(trailId).listen(
      (list) {
        _reviews = list;
        notifyListeners();
      },
      onError: (e) => debugPrint('ReviewProvider stream error: $e'),
    );
  }

  @override
  void dispose() {
    _sub?.cancel();
    super.dispose();
  }

  Future<bool> submit({
    required String trailId,
    required String trailName,
    required int rating,
    required String text,
    required String condition,
  }) async {
    _error = null;
    _submitting = true;
    notifyListeners();

    try {
      if (!kSupabaseAvailable) {
        _error = 'Supabase not configured - reviews require a live connection.';
        return false;
      }
      final uid = _uid;
      if (uid == null) {
        _error = 'Sign in to leave a review.';
        return false;
      }
      await ReviewService.addReview(Review(
        id: '',
        trailId: trailId,
        trailName: trailName,
        rating: rating,
        text: text.trim(),
        condition: condition,
        deviceId: uid,
        userId: uid,
        createdAt: DateTime.now(),
      ));
      return true;
    } catch (e) {
      _error = e.toString();
      return false;
    } finally {
      _submitting = false;
      notifyListeners();
    }
  }

  /// Returns true if [review] was written by the currently signed-in user.
  bool isOwner(Review review) {
    final uid = _uid;
    if (uid == null) return false;
    return review.userId == uid || review.deviceId == uid;
  }

  Future<bool> updateReview(Review review) async {
    try {
      await ReviewService.updateReview(review);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<bool> deleteReview(String reviewId) async {
    try {
      await ReviewService.deleteReview(reviewId);
      return true;
    } catch (e) {
      _error = e.toString();
      notifyListeners();
      return false;
    }
  }

  ReviewSummary get summary => ReviewSummary.fromList(_reviews);
}
