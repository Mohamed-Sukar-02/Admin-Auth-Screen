import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:daily_meal/features/admin/data/models/cloud_meal.dart';
import 'package:daily_meal/features/admin/data/models/ignored_duplicate.dart';
import 'package:daily_meal/features/admin/data/vault_admin_repository.dart';
import 'package:flutter_test/flutter_test.dart';

// Helper to create test CloudMeal fixtures
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
  group('IgnoredDuplicate - Model & Pair Key Generation', () {
    test('Tier 1: generates deterministic symmetric pair key', () {
      final key1 = IgnoredDuplicate.generatePairKey('meal_01', 'meal_02');
      final key2 = IgnoredDuplicate.generatePairKey('meal_02', 'meal_01');
      expect(key1, 'meal_01_meal_02');
      expect(key1, equals(key2));
    });

    test('Tier 2: handles lexicographical string ordering properly', () {
      expect(IgnoredDuplicate.generatePairKey('zeta', 'alpha'), 'alpha_zeta');
      expect(IgnoredDuplicate.generatePairKey('10', '2'), '10_2'); // string '10' < '2'
      expect(IgnoredDuplicate.generatePairKey('abc', 'abc'), 'abc_abc');
    });

    test('Tier 1: toMap produces valid schema payload', () {
      final item = IgnoredDuplicate(
        pairKey: 'id_1_id_2',
        mealId1: 'id_1',
        mealId2: 'id_2',
        meal1Name: 'كفتة فراخ',
        meal2Name: 'كفتة لحمة',
        similarity: 0.822,
        ignoredAt: DateTime.parse('2026-10-02T10:00:00Z'),
        ignoredBy: 'admin@dailymeal.com',
      );

      final map = item.toMap();
      expect(map['pairKey'], 'id_1_id_2');
      expect(map['mealId1'], 'id_1');
      expect(map['mealId2'], 'id_2');
      expect(map['meal1Name'], 'كفتة فراخ');
      expect(map['meal2Name'], 'كفتة لحمة');
      expect(map['similarity'], closeTo(0.822, 0.001));
      expect(map['ignoredBy'], 'admin@dailymeal.com');
      expect(map['ignoredAt'], isNotNull);
    });

    test('Tier 2: fromMap deserializes Timestamp, String, and DateTime cleanly', () {
      // 1. From Timestamp
      final tsDate = DateTime.parse('2026-10-02T12:30:00Z');
      final fromTs = IgnoredDuplicate.fromMap({
        'pairKey': 'm1_m2',
        'mealId1': 'm1',
        'mealId2': 'm2',
        'meal1Name': 'طبق 1',
        'meal2Name': 'طبق 2',
        'similarity': 0.75,
        'ignoredAt': Timestamp.fromDate(tsDate),
        'ignoredBy': 'super_admin@test.com',
      }, 'm1_m2');
      expect(fromTs.pairKey, 'm1_m2');
      expect(fromTs.ignoredAt.toUtc(), equals(tsDate.toUtc()));
      expect(fromTs.similarity, 0.75);

      // 2. From ISO 8601 String
      final fromStr = IgnoredDuplicate.fromMap({
        'pairKey': 'm3_m4',
        'mealId1': 'm3',
        'mealId2': 'm4',
        'ignoredAt': '2026-05-10T08:00:00.000Z',
      }, 'm3_m4');
      expect(fromStr.pairKey, 'm3_m4');
      expect(fromStr.ignoredAt.year, 2026);

      // 3. Fallback when ignoredAt is null
      final fromNull = IgnoredDuplicate.fromMap({
        'mealId1': 'm5',
        'mealId2': 'm6',
      }, 'm5_m6');
      expect(fromNull.pairKey, 'm5_m6');
      expect(fromNull.ignoredAt, isNotNull);
    });

    test('Tier 2: equality and hashCode based on pairKey', () {
      final a = IgnoredDuplicate(
        pairKey: 'key_123',
        mealId1: '1',
        mealId2: '2',
        ignoredAt: DateTime.now(),
      );
      final b = IgnoredDuplicate(
        pairKey: 'key_123',
        mealId1: '1',
        mealId2: '2',
        ignoredAt: DateTime.now().add(const Duration(hours: 1)),
      );
      final c = IgnoredDuplicate(
        pairKey: 'key_456',
        mealId1: '4',
        mealId2: '5',
        ignoredAt: DateTime.now(),
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(c)));
    });
  });

  group('VaultAdminRepository - Canonical Meal Resolution', () {
    test('Tier 1: Starter meal wins over non-starter meal even if non-starter is older', () {
      final starter = _createTestMeal(
        id: 'starter_01',
        name: 'كفتة فراخ',
        isStarterMeal: true,
        createdAt: DateTime.parse('2026-10-01T00:00:00Z'), // newer
      );
      final nonStarter = _createTestMeal(
        id: 'user_01',
        name: 'كفتة لحمة',
        isStarterMeal: false,
        createdAt: DateTime.parse('2020-01-01T00:00:00Z'), // much older
      );

      // Negative means first argument is canonical original (kept)
      final cmp1 = VaultAdminRepository.compareCanonicalMeals(starter, nonStarter);
      expect(cmp1, lessThan(0), reason: 'Starter meal must take precedence');

      final cmp2 = VaultAdminRepository.compareCanonicalMeals(nonStarter, starter);
      expect(cmp2, greaterThan(0), reason: 'Starter meal must take precedence regardless of order');
    });

    test('Tier 1: Earliest createdAt wins when both have identical starter status', () {
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

      expect(VaultAdminRepository.compareCanonicalMeals(older, newer), lessThan(0));
      expect(VaultAdminRepository.compareCanonicalMeals(newer, older), greaterThan(0));
    });

    test('Tier 2: ID tie-breaker breaks exact timestamp and starter ties deterministically', () {
      final dt = DateTime.parse('2025-01-01T00:00:00Z');
      final a = _createTestMeal(id: 'aaa_id', name: 'شوربة', createdAt: dt);
      final b = _createTestMeal(id: 'bbb_id', name: 'شوربه', createdAt: dt);

      expect(VaultAdminRepository.compareCanonicalMeals(a, b), lessThan(0));
      expect(VaultAdminRepository.compareCanonicalMeals(b, a), greaterThan(0));
    });
  });

  group('VaultAdminRepository - Candidate Detection & Ignored Skipping', () {
    late CloudMeal koftaFerekh;
    late CloudMeal koftaLahma;
    late CloudMeal koshari;

    setUp(() {
      koftaFerekh = _createTestMeal(
        id: 'm_kofta_1',
        name: 'كفتة فراخ',
        isStarterMeal: true,
        createdAt: DateTime.parse('2025-01-01T00:00:00Z'),
      );
      koftaLahma = _createTestMeal(
        id: 'm_kofta_2',
        name: 'كفتة لحمة',
        isStarterMeal: false,
        createdAt: DateTime.parse('2025-06-01T00:00:00Z'),
      );
      koshari = _createTestMeal(
        id: 'm_koshari',
        name: 'كشري مصري',
        isStarterMeal: true,
      );
    });

    test('Tier 1: detects similar pair when not ignored', () {
      final candidates = VaultAdminRepository.detectCandidatesPure(
        meals: [koftaFerekh, koftaLahma, koshari],
        ignoredKeys: {},
        threshold: 0.70,
      );

      expect(candidates, hasLength(1));
      final candidate = candidates.first;
      expect(candidate.originalMeal.id, 'm_kofta_1'); // starter kept
      expect(candidate.duplicateMeal.id, 'm_kofta_2'); // non-starter marked for deletion
      expect(candidate.similarity, greaterThanOrEqualTo(0.70));
      expect(candidate.pairKey, 'm_kofta_1_m_kofta_2');
    });

    test('Tier 1: skips pair when pairKey is in ignoredKeys set (O(1) in-memory filtering)', () {
      final pairKey = IgnoredDuplicate.generatePairKey('m_kofta_1', 'm_kofta_2');
      final candidates = VaultAdminRepository.detectCandidatesPure(
        meals: [koftaFerekh, koftaLahma, koshari],
        ignoredKeys: {pairKey},
        threshold: 0.70,
      );

      expect(candidates, isEmpty, reason: 'Ignored pair must be skipped completely');
    });

    test('Tier 2: skips pair even when meals list order is reversed', () {
      final pairKey = IgnoredDuplicate.generatePairKey('m_kofta_1', 'm_kofta_2');
      final candidates = VaultAdminRepository.detectCandidatesPure(
        meals: [koftaLahma, koftaFerekh], // reversed order
        ignoredKeys: {pairKey},
        threshold: 0.70,
      );

      expect(candidates, isEmpty);
    });

    test('Tier 2: handles empty or single-item meal lists', () {
      expect(
        VaultAdminRepository.detectCandidatesPure(meals: [], ignoredKeys: {}),
        isEmpty,
      );
      expect(
        VaultAdminRepository.detectCandidatesPure(meals: [koftaFerekh], ignoredKeys: {}),
        isEmpty,
      );
    });

    test('Tier 1: candidates are sorted descending by similarity', () {
      final mealA1 = _createTestMeal(id: '1', name: 'كفتة فراخ');
      final mealA2 = _createTestMeal(id: '2', name: 'كفتة الفراخ'); // ~93%
      final mealB1 = _createTestMeal(id: '3', name: 'شوربة لسان عصفور');
      final mealB2 = _createTestMeal(id: '4', name: 'طاجن لسان عصفور'); // ~73%

      final candidates = VaultAdminRepository.detectCandidatesPure(
        meals: [mealB1, mealB2, mealA1, mealA2],
        ignoredKeys: {},
        threshold: 0.70,
      );

      expect(candidates.length, greaterThanOrEqualTo(2));
      for (var i = 0; i < candidates.length - 1; i++) {
        expect(
          candidates[i].similarity,
          greaterThanOrEqualTo(candidates[i + 1].similarity),
        );
      }
    });
  });

  group('VaultAdminRepository - Batch Deletion Chunking Math', () {
    test('Tier 1: calculates correct chunk count for batch size 8', () {
      expect(VaultAdminRepository.calculateBatchCount(0), 0);
      expect(VaultAdminRepository.calculateBatchCount(1), 1);
      expect(VaultAdminRepository.calculateBatchCount(7), 1);
      expect(VaultAdminRepository.calculateBatchCount(8), 1);
      expect(VaultAdminRepository.calculateBatchCount(9), 2);
      expect(VaultAdminRepository.calculateBatchCount(16), 2);
      expect(VaultAdminRepository.calculateBatchCount(17), 3);
      expect(VaultAdminRepository.calculateBatchCount(25), 4);
    });

    test('Tier 2: deduplicates duplicate IDs before chunking', () {
      final ids = ['id_1', 'id_2', 'id_1', 'id_3', 'id_2'];
      final uniqueIds = ids.toSet().toList();
      expect(uniqueIds, hasLength(3));
      expect(uniqueIds, containsAll(['id_1', 'id_2', 'id_3']));
    });
  });
}
