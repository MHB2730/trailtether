class Review {
  final String id;
  final String trailId;
  final String trailName;
  final int rating; // 1–5
  final String text;
  final String condition; // 'good' | 'fair' | 'poor' | ''
  final String deviceId; // legacy anonymous id
  final String userId; // Supabase user id of the author
  final DateTime createdAt;
  final DateTime? updatedAt;

  const Review({
    required this.id,
    required this.trailId,
    required this.trailName,
    required this.rating,
    required this.text,
    required this.condition,
    required this.deviceId,
    required this.userId,
    required this.createdAt,
    this.updatedAt,
  });

  factory Review.fromMap(Map<String, dynamic> d) => Review(
        id: d['id'] as String? ?? '',
        trailId: d['trail_id'] as String? ?? '',
        trailName: d['trail_name'] as String? ?? '',
        rating: (d['rating'] as num?)?.toInt() ?? 0,
        text: d['review_text'] as String? ?? d['text'] as String? ?? '',
        condition: d['condition'] as String? ?? '',
        deviceId: d['device_id'] as String? ?? '',
        userId: d['user_id'] as String? ?? '',
        createdAt: _parseDate(d['created_at']),
        updatedAt: d['updated_at'] != null ? _parseDate(d['updated_at']) : null,
      );

  Map<String, dynamic> toInsertMap() => {
        'trail_id': trailId,
        'trail_name': trailName,
        'rating': rating,
        'review_text': text,
        'condition': condition,
        'device_id': deviceId,
        'user_id': userId.isEmpty ? null : userId,
      };

  Map<String, dynamic> toUpdateMap() => {
        'rating': rating,
        'review_text': text,
        'condition': condition,
        'updated_at': DateTime.now().toIso8601String(),
      };

  Review copyWith({int? rating, String? text, String? condition}) => Review(
        id: id,
        trailId: trailId,
        trailName: trailName,
        rating: rating ?? this.rating,
        text: text ?? this.text,
        condition: condition ?? this.condition,
        deviceId: deviceId,
        userId: userId,
        createdAt: createdAt,
        updatedAt: updatedAt,
      );

  static DateTime _parseDate(dynamic raw) {
    if (raw is String) return DateTime.parse(raw).toLocal();
    return DateTime.now();
  }
}

class ReviewSummary {
  final double averageRating;
  final int count;
  const ReviewSummary({required this.averageRating, required this.count});

  static const empty = ReviewSummary(averageRating: 0, count: 0);

  factory ReviewSummary.fromList(List<Review> reviews) {
    if (reviews.isEmpty) return empty;
    final avg =
        reviews.map((r) => r.rating).reduce((a, b) => a + b) / reviews.length;
    return ReviewSummary(averageRating: avg, count: reviews.length);
  }
}
