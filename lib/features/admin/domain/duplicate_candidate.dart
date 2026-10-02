import '../data/models/cloud_meal.dart';
import '../data/models/ignored_duplicate.dart';

/// Represents a candidate duplicate pair discovered by the similarity engine.
///
/// Designated via strict canonical ordering:
/// - [originalMeal] is the preserved dish (starter pack priority, then earliest createdAt).
/// - [duplicateMeal] is the candidate for deletion.
class DuplicatePairCandidate {
  final CloudMeal originalMeal;
  final CloudMeal duplicateMeal;
  final double similarity;

  const DuplicatePairCandidate({
    required this.originalMeal,
    required this.duplicateMeal,
    required this.similarity,
  });

  /// Deterministic symmetric pair key for checking against `ignored_duplicates`.
  String get pairKey =>
      IgnoredDuplicate.generatePairKey(originalMeal.id, duplicateMeal.id);

  /// Formatted similarity percentage (e.g. "82%")
  String get similarityPercentage =>
      '${(similarity * 100).toStringAsFixed(0)}%';

  /// Strict canonical comparator to determine which meal should be kept as original.
  /// Returns negative if [a] takes precedence (kept), positive if [b] takes precedence.
  ///
  /// 3-tier precedence:
  /// 1. Starter pack meal (`isStarterMeal == true`) > Non-starter
  /// 2. Earliest `createdAt`
  /// 3. Lexicographical ID tie-breaker
  static int compareCanonicalMeals(CloudMeal a, CloudMeal b) {
    // 1. Starter pack meal takes top precedence
    if (a.isStarterMeal != b.isStarterMeal) {
      return a.isStarterMeal ? -1 : 1;
    }

    // 2. Chronologically older meal takes precedence
    final cmp = a.createdAt.compareTo(b.createdAt);
    if (cmp != 0) return cmp;

    // 3. Document ID tie-breaker
    return a.id.compareTo(b.id);
  }

  /// Resolves canonical original meal vs duplicate meal based on 3-tier precedence.
  factory DuplicatePairCandidate.resolve({
    required CloudMeal mealA,
    required CloudMeal mealB,
    required double similarity,
  }) {
    final cmp = compareCanonicalMeals(mealA, mealB);
    if (cmp <= 0) {
      return DuplicatePairCandidate(
        originalMeal: mealA,
        duplicateMeal: mealB,
        similarity: similarity,
      );
    } else {
      return DuplicatePairCandidate(
        originalMeal: mealB,
        duplicateMeal: mealA,
        similarity: similarity,
      );
    }
  }

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is DuplicatePairCandidate &&
          runtimeType == other.runtimeType &&
          pairKey == other.pairKey;

  @override
  int get hashCode => pairKey.hashCode;
}

/// Convenience alias
typedef DuplicateCandidate = DuplicatePairCandidate;
