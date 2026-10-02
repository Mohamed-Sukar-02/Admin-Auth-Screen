import 'package:cloud_firestore/cloud_firestore.dart';

/// Model representing a meal pair that the admin has explicitly marked as
/// "Not similar" (ignored) so they are never flagged again by deduplication.
///
/// Stored in Firestore `/ignored_duplicates/{pairKey}` where `pairKey` is
/// deterministic and symmetric: `${min(idA, idB)}_${max(idA, idB)}`.
class IgnoredDuplicate {
  final String pairKey;
  final String mealId1;
  final String mealId2;
  final String? meal1Name;
  final String? meal2Name;
  final double? similarity;
  final DateTime ignoredAt;
  final String? ignoredBy;

  const IgnoredDuplicate({
    required this.pairKey,
    required this.mealId1,
    required this.mealId2,
    this.meal1Name,
    this.meal2Name,
    this.similarity,
    required this.ignoredAt,
    this.ignoredBy,
  });

  /// Deterministically creates a symmetric pair key using lexicographical ordering:
  /// min(id1, id2) + "_" + max(id1, id2)
  static String generatePairKey(String id1, String id2) {
    return id1.compareTo(id2) <= 0 ? '${id1}_$id2' : '${id2}_$id1';
  }

  /// Serializes to Firestore document map.
  /// Matches schema keys: 'pairKey', 'mealId1', 'mealId2', 'ignoredAt', etc.
  Map<String, dynamic> toMap({bool useServerTimestamp = false}) {
    return {
      'pairKey': pairKey,
      'mealId1': mealId1,
      'mealId2': mealId2,
      if (meal1Name != null) 'meal1Name': meal1Name,
      if (meal2Name != null) 'meal2Name': meal2Name,
      if (similarity != null) 'similarity': similarity,
      'ignoredAt': useServerTimestamp
          ? FieldValue.serverTimestamp()
          : Timestamp.fromDate(ignoredAt),
      if (ignoredBy != null && ignoredBy!.trim().isNotEmpty)
        'ignoredBy': ignoredBy!.trim(),
    };
  }

  /// Deserializes from a map and document ID. Handles Timestamp, ISO 8601 String, or DateTime.
  factory IgnoredDuplicate.fromMap(Map<String, dynamic> map, String docId) {
    final rawDate = map['ignoredAt'];
    DateTime parsedDate;
    if (rawDate is Timestamp) {
      parsedDate = rawDate.toDate();
    } else if (rawDate is String) {
      parsedDate = DateTime.tryParse(rawDate) ?? DateTime.now();
    } else if (rawDate is DateTime) {
      parsedDate = rawDate;
    } else {
      parsedDate = DateTime.now();
    }

    return IgnoredDuplicate(
      pairKey: docId,
      mealId1: map['mealId1'] as String? ?? '',
      mealId2: map['mealId2'] as String? ?? '',
      meal1Name: map['meal1Name'] as String?,
      meal2Name: map['meal2Name'] as String?,
      similarity: (map['similarity'] as num?)?.toDouble(),
      ignoredAt: parsedDate,
      ignoredBy: map['ignoredBy'] as String?,
    );
  }

  /// Deserializes from Firestore DocumentSnapshot.
  factory IgnoredDuplicate.fromFirestore(
    DocumentSnapshot<Map<String, dynamic>> doc,
  ) {
    return IgnoredDuplicate.fromMap(doc.data() ?? {}, doc.id);
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is IgnoredDuplicate &&
          runtimeType == other.runtimeType &&
          pairKey == other.pairKey;

  @override
  int get hashCode => pairKey.hashCode;
}
