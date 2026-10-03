import 'package:daily_meal/features/admin/data/models/cloud_meal.dart';
import 'package:daily_meal/features/admin/domain/duplicate_candidate.dart';
import 'package:daily_meal/features/admin/domain/similarity_engine.dart';
import 'package:flutter_test/flutter_test.dart';

CloudMeal _createTestMeal({
  required String id,
  required String name,
  bool isStarterMeal = false,
  DateTime? createdAt,
}) {
  return CloudMeal(
    id: id,
    name: name,
    proteinType: 'chicken',
    carbsType: 'rice',
    category: 'tabeekh',
    prepTimeMinutes: 30,
    isFridaySpecial: false,
    isStarterMeal: isStarterMeal,
    createdAt: createdAt ?? DateTime.parse('2026-01-01T12:00:00Z'),
    status: 'approved',
  );
}

void main() {
  group('SimilarityEngine - normalizeArabic', () {
    test('Tier 1: strips Tashkeel (harakat) completely', () {
      expect(SimilarityEngine.normalizeArabic('كُفْتَةٌ لَحْمَةٍ'), 'كفته لحمه');
      expect(SimilarityEngine.normalizeArabic('مَلُوخِيَّةٌ خَضْرَاءُ'), 'ملوخيه خضراء');
      expect(SimilarityEngine.normalizeArabic('شَوْرَبَةُ دَجَاجٍ'), 'شوربه دجاج');
      expect(SimilarityEngine.normalizeArabic('أَرُزٌّ بِاللَّبَنِ'), 'ارز باللبن');
    });

    test('Tier 1: strips Tatweel (kashida)', () {
      expect(SimilarityEngine.normalizeArabic('كــــفتة'), 'كفته');
      expect(SimilarityEngine.normalizeArabic('أرز باللبـــــن'), 'ارز باللبن');
    });

    test('Tier 1: unifies Alef variants [أ, إ, آ, ٱ] to bare Alef [ا]', () {
      expect(SimilarityEngine.normalizeArabic('أرز'), 'ارز');
      expect(SimilarityEngine.normalizeArabic('إيدام'), 'ايدام');
      expect(SimilarityEngine.normalizeArabic('آيس كريم'), 'ايس كريم');
      expect(SimilarityEngine.normalizeArabic('ٱرز مصري'), 'ارز مصري');
    });

    test('Tier 1: unifies Taa Marbuta [ة] to Haa [ه]', () {
      expect(SimilarityEngine.normalizeArabic('كفتة'), 'كفته');
      expect(SimilarityEngine.normalizeArabic('ملوخية'), 'ملوخيه');
      expect(SimilarityEngine.normalizeArabic('صينية بطاطس'), 'صينيه بطاطس');
    });

    test('Tier 1: unifies Alef Maqsura [ى] to Yaa [ي]', () {
      expect(SimilarityEngine.normalizeArabic('سمك مقلى'), 'سمك مقلي');
      expect(SimilarityEngine.normalizeArabic('حلوى'), 'حلوي');
      expect(SimilarityEngine.normalizeArabic('مشوى'), 'مشوي');
    });

    test('Tier 1: converts Eastern Arabic and Perso-Arabic numerals to ASCII', () {
      expect(SimilarityEngine.normalizeArabic('وجبة رقم ٥'), 'وجبه رقم 5');
      expect(SimilarityEngine.normalizeArabic('شاورما ٠١٢٣٤٥٦٧٨٩'), 'شاورما 0123456789');
      expect(SimilarityEngine.normalizeArabic('وجبة ۰۱۲۳۴۵۶۷۸۹'), 'وجبه 0123456789');
    });

    test('Tier 1: collapses multiple whitespaces and trims edges', () {
      expect(SimilarityEngine.normalizeArabic('   كفتة    فراخ   '), 'كفته فراخ');
      expect(SimilarityEngine.normalizeArabic('\tكشري\nمصري\r\n'), 'كشري مصري');
    });

    test('Tier 1: strips punctuation without stripping Arabic characters (Unicode safety)', () {
      expect(SimilarityEngine.normalizeArabic('كفتة (فراخ) - مشوية!'), 'كفته فراخ مشويه');
      expect(SimilarityEngine.normalizeArabic('طاجن بامية/لحمة؟'), 'طاجن باميه لحمه');
      expect(SimilarityEngine.normalizeArabic('"شاورما" [دجاج]'), 'شاورما دجاج');
    });

    test('Tier 1: strips invisible Unicode control characters', () {
      // ZWSP \u200B, LTR \u200E, RTL \u200F, NBSP \u00A0
      expect(
        SimilarityEngine.normalizeArabic('كفتة\u00A0\u200B\u200E\u200Fفراخ'),
        'كفته فراخ',
      );
    });

    test('Tier 1: preserves English alphanumerics and digits', () {
      expect(SimilarityEngine.normalizeArabic('Pizza 123 Hot'), 'pizza 123 hot');
      expect(SimilarityEngine.normalizeArabic('وجبة رقم 1'), 'وجبه رقم 1');
      expect(SimilarityEngine.normalizeArabic('Burger فراخ'), 'burger فراخ');
    });

    test('Tier 2: handles empty and whitespace-only strings', () {
      expect(SimilarityEngine.normalizeArabic(''), '');
      expect(SimilarityEngine.normalizeArabic('   '), '');
      expect(SimilarityEngine.normalizeArabic('\n\t\r'), '');
    });

    test('Tier 2: handles diacritics and punctuation-only strings', () {
      expect(SimilarityEngine.normalizeArabic('ًٌٍَُِّْـ-–—!؟()[]{}'), '');
    });

    test('Tier 2: idempotent normalization', () {
      final once = SimilarityEngine.normalizeArabic('أرز باللبن و المكسرات');
      final twice = SimilarityEngine.normalizeArabic(once);
      expect(once, twice);
    });
  });

  group('SimilarityEngine - Jaro-Winkler Metric', () {
    test('Tier 1: returns 1.0 for identical strings', () {
      expect(SimilarityEngine.jaroWinkler('كفتة فراخ', 'كفتة فراخ'), closeTo(1.0, 0.0001));
      expect(SimilarityEngine.jaroWinkler('abc', 'abc'), closeTo(1.0, 0.0001));
    });

    test('Tier 1: returns 0.0 for completely disjoint strings', () {
      expect(SimilarityEngine.jaroWinkler('abc', 'xyz'), closeTo(0.0, 0.0001));
    });

    test('Tier 2: is symmetric: jaroWinkler(a, b) == jaroWinkler(b, a)', () {
      final s1 = SimilarityEngine.jaroWinkler('كفتة فراخ', 'كفتة لحمة');
      final s2 = SimilarityEngine.jaroWinkler('كفتة لحمة', 'كفتة فراخ');
      expect(s1, equals(s2));
    });

    test('Tier 2: handles empty strings', () {
      expect(SimilarityEngine.jaroWinkler('', ''), closeTo(1.0, 0.0001));
      expect(SimilarityEngine.jaroWinkler('كفتة', ''), closeTo(0.0, 0.0001));
      expect(SimilarityEngine.jaroWinkler('', 'كفتة'), closeTo(0.0, 0.0001));
    });

    test('Tier 1: scores "كفتة فراخ" vs "كفتة لحمة" above 0.80 due to common prefix', () {
      final score = SimilarityEngine.jaroWinkler('كفته فراخ', 'كفته لحمه');
      expect(score, greaterThanOrEqualTo(0.80));
    });
  });

  group('SimilarityEngine - Levenshtein Distance & Ratio', () {
    test('Tier 1: returns 1.0 for identical strings', () {
      expect(SimilarityEngine.levenshteinSimilarity('كفتة', 'كفتة'), closeTo(1.0, 0.0001));
      expect(SimilarityEngine.levenshteinDistance('كفتة', 'كفتة'), 0);
    });

    test('Tier 1: calculates edit distance and ratio accurately', () {
      // 1 deletion: 'كفته' to 'كفت' distance = 1, ratio = 1 - 1/4 = 0.75
      expect(SimilarityEngine.levenshteinDistance('كفته', 'كفت'), 1);
      expect(SimilarityEngine.levenshteinSimilarity('كفته', 'كفت'), closeTo(0.75, 0.0001));
    });

    test('Tier 2: is symmetric', () {
      final s1 = SimilarityEngine.levenshteinSimilarity('كشري مصري', 'ملوخية خضراء');
      final s2 = SimilarityEngine.levenshteinSimilarity('ملوخية خضراء', 'كشري مصري');
      expect(s1, equals(s2));
    });

    test('Tier 2: handles empty strings', () {
      expect(SimilarityEngine.levenshteinSimilarity('', ''), closeTo(1.0, 0.0001));
      expect(SimilarityEngine.levenshteinSimilarity('كشري', ''), closeTo(0.0, 0.0001));
      expect(SimilarityEngine.levenshteinSimilarity('', 'كشري'), closeTo(0.0, 0.0001));
      expect(SimilarityEngine.levenshteinDistance('كشري', ''), 4);
      expect(SimilarityEngine.levenshteinDistance('', 'كشري'), 4);
    });
  });

  group('SimilarityEngine - Composite Metric & Threshold', () {


    test('Tier 1: areSimilar uses 0.88 default threshold', () {
      expect(SimilarityEngine.areSimilar('كفتة فراخ', 'كفتة لحمة'), isFalse);
      expect(SimilarityEngine.areSimilar('كشري مصري', 'ملوخية خضراء'), isFalse);
    });

    test('Tier 2: areSimilar respects custom threshold', () {
      expect(SimilarityEngine.areSimilar('كفتة فراخ', 'كفتة لحمة', threshold: 0.95), isFalse);
      expect(SimilarityEngine.areSimilar('كفتة فراخ', 'كفته فراخ', threshold: 0.95), isTrue);
    });

    test('Tier 2: defensive guard returns 0.0 for empty or punctuation-only strings', () {
      expect(SimilarityEngine.compositeSimilarity('', ''), 0.0);
      expect(SimilarityEngine.compositeSimilarity('---', '---'), 0.0);
      expect(SimilarityEngine.compositeSimilarity('كفتة', ''), 0.0);
    });
  });

  group('SimilarityEngine - Egyptian Meal Benchmark Pairs', () {
    test('Negative Benchmark 1: "كفتة فراخ" vs "كفتة لحمة" (Now < 50% due to Jaccard gating)', () {
      final sim = SimilarityEngine.compositeSimilarity('كفتة فراخ', 'كفتة لحمة');
      expect(sim, lessThan(0.50));
      expect(SimilarityEngine.areSimilar('كفتة فراخ', 'كفتة لحمة'), isFalse);
    });

    test('Positive Benchmark 2: "كفتة فراخ" vs "كفته فراخ" (Taa Marbuta variation)', () {
      expect(SimilarityEngine.compositeSimilarity('كفتة فراخ', 'كفته فراخ'), closeTo(1.0, 0.0001));
      expect(SimilarityEngine.areSimilar('كفتة فراخ', 'كفته فراخ'), isTrue);
    });

    test('Positive Benchmark 3: "أرز باللبن" vs "ارز باللبن" (Alef variation)', () {
      expect(SimilarityEngine.compositeSimilarity('أرز باللبن', 'ارز باللبن'), closeTo(1.0, 0.0001));
      expect(SimilarityEngine.areSimilar('أرز باللبن', 'ارز باللبن'), isTrue);
    });

    test('Positive Benchmark 4: "كفتة فراخ" vs "كفتة الفراخ" (Definite article prefix)', () {
      expect(SimilarityEngine.areSimilar('كفتة فراخ', 'كفتة الفراخ'), isTrue);
    });

    test('Positive Benchmark 5: "كفتة فراخ مشوية" vs "كفتة فراخ" (Attribute suffix)', () {
      expect(SimilarityEngine.areSimilar('كفتة فراخ مشوية', 'كفتة فراخ'), isTrue);
    });

    test('Negative Benchmark 6: "شاورما فراخ" vs "شاورما لحمة" (Protein variation)', () {
      expect(SimilarityEngine.areSimilar('شاورما فراخ', 'شاورما لحمة'), isFalse);
    });

    test('Negative Benchmark 7: "ملوخية بالفراخ" vs "ملوخية بالارانب"', () {
      expect(SimilarityEngine.areSimilar('ملوخية بالفراخ', 'ملوخية بالارانب'), isFalse);
    });

    test('Positive Benchmark 8: "مكرونة بشاميل" vs "مكرونة بالبشاميل"', () {
      expect(SimilarityEngine.areSimilar('مكرونة بشاميل', 'مكرونة بالبشاميل'), isTrue);
    });

    test('Negative Benchmark 9: "شوربة لسان عصفور" vs "طاجن لسان عصفور"', () {
      expect(SimilarityEngine.areSimilar('شوربة لسان عصفور', 'طاجن لسان عصفور'), isFalse);
    });

    test('Positive Benchmark 10: "وجبة 1" vs "وجبة ١" (Eastern Arabic numeral)', () {
      expect(SimilarityEngine.compositeSimilarity('وجبة 1', 'وجبة ١'), closeTo(1.0, 0.0001));
      expect(SimilarityEngine.areSimilar('وجبة 1', 'وجبة ١'), isTrue);
    });

    test('Negative Benchmark 1: "كشري مصري" vs "ملوخية خضراء" (< 70%)', () {
      final sim = SimilarityEngine.compositeSimilarity('كشري مصري', 'ملوخية خضراء');
      expect(sim, lessThan(0.70));
      expect(SimilarityEngine.areSimilar('كشري مصري', 'ملوخية خضراء'), isFalse);
    });

    test('Negative Benchmark 2: "سمك بلطي مشوي" vs "كفتة لحمة مشوية" (< 70%)', () {
      final sim = SimilarityEngine.compositeSimilarity('سمك بلطي مشوي', 'كفتة لحمة مشوية');
      expect(sim, lessThan(0.70));
      expect(SimilarityEngine.areSimilar('سمك بلطي مشوي', 'كفتة لحمة مشوية'), isFalse);
    });

    test('Negative Benchmark 3: "فول مدمس" vs "بامية باللحمة" (< 70%)', () {
      expect(SimilarityEngine.areSimilar('فول مدمس', 'بامية باللحمة'), isFalse);
    });

    test('Negative Benchmark 4: "بيتزا مارجريتا" vs "كشري مصري" (< 70%)', () {
      expect(SimilarityEngine.areSimilar('بيتزا مارجريتا', 'كشري مصري'), isFalse);
    });

    test('Negative Benchmark 5: "فول مدمس" vs "فلافل مصرية" (< 70%)', () {
      final sim = SimilarityEngine.compositeSimilarity('فول مدمس', 'فلافل مصرية');
      expect(sim, lessThan(0.70));
      expect(SimilarityEngine.areSimilar('فول مدمس', 'فلافل مصرية'), isFalse);
    });
  });

  group('DuplicatePairCandidate - Canonical Ordering & Resolution', () {
    test('Tier 1: Starter meal beats non-starter meal even if non-starter is older', () {
      final starter = _createTestMeal(
        id: 'starter_01',
        name: 'كفتة فراخ',
        isStarterMeal: true,
        createdAt: DateTime.parse('2026-10-01T00:00:00Z'),
      );
      final nonStarter = _createTestMeal(
        id: 'user_01',
        name: 'كفتة لحمة',
        isStarterMeal: false,
        createdAt: DateTime.parse('2020-01-01T00:00:00Z'),
      );

      final candidate1 = DuplicatePairCandidate.resolve(
        mealA: starter,
        mealB: nonStarter,
        similarity: 0.82,
      );
      expect(candidate1.originalMeal.id, 'starter_01');
      expect(candidate1.duplicateMeal.id, 'user_01');

      // Order reversed in call: result must be identical
      final candidate2 = DuplicatePairCandidate.resolve(
        mealA: nonStarter,
        mealB: starter,
        similarity: 0.82,
      );
      expect(candidate2.originalMeal.id, 'starter_01');
      expect(candidate2.duplicateMeal.id, 'user_01');
    });

    test('Tier 1: Earliest createdAt wins when starter status is identical', () {
      final older = _createTestMeal(
        id: 'm1',
        name: 'كفتة فراخ',
        isStarterMeal: false,
        createdAt: DateTime.parse('2024-01-01T00:00:00Z'),
      );
      final newer = _createTestMeal(
        id: 'm2',
        name: 'كفتة لحمة',
        isStarterMeal: false,
        createdAt: DateTime.parse('2025-01-01T00:00:00Z'),
      );

      final candidate = DuplicatePairCandidate.resolve(
        mealA: newer,
        mealB: older,
        similarity: 0.82,
      );
      expect(candidate.originalMeal.id, 'm1');
      expect(candidate.duplicateMeal.id, 'm2');
    });

    test('Tier 2: Lexicographical ID tie-breaker when timestamp and starter status match', () {
      final dt = DateTime.parse('2025-01-01T00:00:00Z');
      final a = _createTestMeal(id: 'aaa_id', name: 'شوربة', createdAt: dt);
      final b = _createTestMeal(id: 'bbb_id', name: 'شوربه', createdAt: dt);

      final candidate = DuplicatePairCandidate.resolve(
        mealA: b,
        mealB: a,
        similarity: 0.95,
      );
      expect(candidate.originalMeal.id, 'aaa_id');
      expect(candidate.duplicateMeal.id, 'bbb_id');
    });

    test('Tier 1: formatting properties and pairKey', () {
      final m1 = _createTestMeal(id: 'id_1', name: 'وجبة 1');
      final m2 = _createTestMeal(id: 'id_2', name: 'وجبة 2');
      final candidate = DuplicatePairCandidate.resolve(
        mealA: m1,
        mealB: m2,
        similarity: 0.854,
      );
      expect(candidate.pairKey, 'id_1_id_2');
      expect(candidate.similarityPercentage, '85%');
    });
  });
}



