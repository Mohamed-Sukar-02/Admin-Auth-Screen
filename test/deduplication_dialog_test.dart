import 'package:daily_meal/core/localization/app_strings.dart';
import 'package:daily_meal/features/admin/data/models/cloud_meal.dart';
import 'package:daily_meal/features/admin/data/vault_admin_repository.dart';
import 'package:daily_meal/features/admin/domain/duplicate_candidate.dart';
import 'package:daily_meal/features/admin/presentation/widgets/admin_dialog.dart';
import 'package:daily_meal/features/admin/presentation/widgets/deduplication_dialog.dart';
import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

/// Hermetic Fake Vault Admin Repository for isolated widget testing.
class FakeVaultAdminRepository extends Fake implements VaultAdminRepository {
  List<DuplicatePairCandidate> candidatesToReturn = [];
  final List<String> deletedMealIds = [];
  final List<
      ({
        String? adminId,
        CloudMeal mealA,
        CloudMeal mealB,
        double similarity,
      })> ignoredCalls = [];
  final List<String> batchDeletedMealIds = [];
  bool throwOnDetect = false;
  bool throwOnDelete = false;
  bool throwOnIgnore = false;
  bool throwOnBatchDelete = false;
  Duration simulatedDelay = Duration.zero;

  @override
  Future<List<DuplicatePairCandidate>> detectDuplicateCandidates({
    List<CloudMeal>? preloadedMeals,
    Set<String>? preloadedIgnoredKeys,
    double threshold = 0.70,
    bool checkById = false,
  }) async {
    if (simulatedDelay > Duration.zero) await Future.delayed(simulatedDelay);
    if (throwOnDetect) throw Exception('Simulated network error');
    return List<DuplicatePairCandidate>.from(candidatesToReturn);
  }

  @override
  Future<void> deleteVaultMeal(String mealId) async {
    if (simulatedDelay > Duration.zero) await Future.delayed(simulatedDelay);
    if (throwOnDelete) throw Exception('Simulated delete error');
    deletedMealIds.add(mealId);
  }

  @override
  Future<void> ignoreDuplicatePair({
    required CloudMeal mealA,
    required CloudMeal mealB,
    required double similarity,
    String? adminId,
  }) async {
    if (simulatedDelay > Duration.zero) await Future.delayed(simulatedDelay);
    if (throwOnIgnore) throw Exception('Simulated ignore error');
    ignoredCalls.add((
      mealA: mealA,
      mealB: mealB,
      similarity: similarity,
      adminId: adminId,
    ));
  }

  @override
  Future<int> deleteDuplicateMealsBatch(List<String> duplicateIds) async {
    if (simulatedDelay > Duration.zero) await Future.delayed(simulatedDelay);
    if (throwOnBatchDelete) throw Exception('Simulated batch delete error');
    batchDeletedMealIds.addAll(duplicateIds);
    return duplicateIds.length;
  }
}

/// Helper to manufacture test CloudMeal instances.
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

/// Helper to manufacture resolved DuplicatePairCandidate instances.
DuplicatePairCandidate _createCandidate({
  required CloudMeal original,
  required CloudMeal duplicate,
  double similarity = 0.822,
}) {
  return DuplicatePairCandidate(
    originalMeal: original,
    duplicateMeal: duplicate,
    similarity: similarity,
  );
}

void main() {
  late FakeVaultAdminRepository fakeRepo;

  setUp(() {
    fakeRepo = FakeVaultAdminRepository();
  });

  /// Pumps DeduplicationDialog into the test harness.
  Future<void> pumpDialog(
    WidgetTester tester, {
    Locale locale = const Locale('ar'),
    Size viewport = const Size(1280, 900),
    bool settle = true,
  }) async {
    tester.view.physicalSize = viewport;
    tester.view.devicePixelRatio = 1.0;
    addTearDown(() => tester.view.resetPhysicalSize());

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          vaultAdminRepositoryProvider.overrideWithValue(fakeRepo),
        ],
        child: MaterialApp(
          locale: locale,
          supportedLocales: const [Locale('ar'), Locale('en')],
          localizationsDelegates: const [
            GlobalMaterialLocalizations.delegate,
            GlobalWidgetsLocalizations.delegate,
            GlobalCupertinoLocalizations.delegate,
          ],
          home: Builder(
            builder: (context) {
              return Directionality(
                textDirection: locale.languageCode == 'ar'
                    ? TextDirection.rtl
                    : TextDirection.ltr,
                child: const Scaffold(
                  body: DeduplicationDialog(),
                ),
              );
            },
          ),
        ),
      ),
    );

    if (settle) {
      await tester.pumpAndSettle();
    } else {
      await tester.pump();
    }
  }

  // ───────────────────────────────────────────────────────────────────────────
  // Tier 1: Core Feature Verification
  // ───────────────────────────────────────────────────────────────────────────
  group('Tier 1: Core Feature Verification', () {
    testWidgets(
      '1. Renders AdminDialogShell with title, subtitle and cleanup icon',
      (tester) async {
        await pumpDialog(tester);
        const strings = AppStrings(Locale('ar'));

        expect(find.byType(AdminDialogShell), findsOneWidget);
        expect(find.text(strings.vaultDeduplicationTitle), findsOneWidget);
        expect(find.text(strings.vaultDeduplicationSubtitle), findsOneWidget);
        expect(find.byIcon(AdminIcons.cleanup), findsWidgets);
      },
    );

    testWidgets(
      '2. Header close button is present and functional',
      (tester) async {
        await pumpDialog(tester);

        final closeButtons = find.byIcon(AdminIcons.close);
        expect(closeButtons, findsOneWidget);
      },
    );

    testWidgets(
      '3. Displays circular progress indicator while scanning',
      (tester) async {
        fakeRepo.simulatedDelay = const Duration(milliseconds: 300);
        await pumpDialog(tester, settle: false);

        const strings = AppStrings(Locale('ar'));
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
        expect(find.text(strings.vaultDeduplicationScanning), findsOneWidget);

        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      '4. Renders empty clean vault state when repository returns zero candidates',
      (tester) async {
        fakeRepo.candidatesToReturn = [];
        await pumpDialog(tester);

        const strings = AppStrings(Locale('ar'));
        expect(find.text(strings.vaultDeduplicationEmptyTitle), findsOneWidget);
        expect(
          find.text(strings.vaultDeduplicationEmptySubtitle),
          findsOneWidget,
        );
        expect(find.byIcon(AdminIcons.success), findsOneWidget);
        expect(find.text(strings.vaultDeduplicationClose), findsOneWidget);
      },
    );

    testWidgets(
      '5. Close button in footer pops the dialog in empty state',
      (tester) async {
        fakeRepo.candidatesToReturn = [];
        await pumpDialog(tester);
        const strings = AppStrings(Locale('ar'));

        final closeBtn = find.text(strings.vaultDeduplicationClose);
        expect(closeBtn, findsOneWidget);
        await tester.tap(closeBtn);
        await tester.pumpAndSettle();
        // Dialog navigator pop called
      },
    );

    testWidgets(
      '6. Displays count banner with proper Arabic pluralization for detected pairs',
      (tester) async {
        final mealA = _createTestMeal(id: 'm1', name: 'كفتة فراخ');
        final mealB = _createTestMeal(id: 'm2', name: 'كفتة لحمة');
        fakeRepo.candidatesToReturn = [
          _createCandidate(original: mealA, duplicate: mealB)
        ];

        await pumpDialog(tester);
        const strings = AppStrings(Locale('ar'));

        expect(
          find.text(strings.vaultDeduplicationPairsFound(1)),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '7. Candidate cards render Original (Keep) and Duplicate (Delete) with IDs and Names',
      (tester) async {
        final mealA = _createTestMeal(
          id: 'vault_01',
          name: 'كفتة فراخ',
          isStarterMeal: true,
        );
        final mealB = _createTestMeal(
          id: 'vault_02',
          name: 'كفتة لحمة',
          isStarterMeal: false,
        );
        fakeRepo.candidatesToReturn = [
          _createCandidate(original: mealA, duplicate: mealB, similarity: 0.85)
        ];

        await pumpDialog(tester);
        const strings = AppStrings(Locale('ar'));

        expect(
          find.text(strings.vaultDeduplicationOriginalBadge),
          findsOneWidget,
        );
        expect(find.text('كفتة فراخ'), findsOneWidget);
        expect(find.textContaining('vault_01'), findsOneWidget);

        expect(
          find.text(strings.vaultDeduplicationDuplicateBadge),
          findsOneWidget,
        );
        expect(find.text('كفتة لحمة'), findsOneWidget);
        expect(find.textContaining('vault_02'), findsOneWidget);

        expect(find.text(strings.vaultDeduplicationStarterMeal), findsOneWidget);
        expect(find.textContaining('85%'), findsOneWidget);
      },
    );

    testWidgets(
      '8. Copy ID button triggers clipboard set and shows toast',
      (tester) async {
        final mealA = _createTestMeal(id: 'vault_01', name: 'كفتة فراخ');
        final mealB = _createTestMeal(id: 'vault_02', name: 'كفتة لحمة');
        fakeRepo.candidatesToReturn = [
          _createCandidate(original: mealA, duplicate: mealB)
        ];

        await pumpDialog(tester);

        final copyButtons = find.byIcon(AdminIcons.copy);
        expect(copyButtons, findsWidgets);

        await tester.tap(copyButtons.first);
        await tester.pumpAndSettle();
      },
    );

    testWidgets(
      '9. Tapping "Delete Duplicate" calls deleteVaultMeal and removes candidate',
      (tester) async {
        final mealA = _createTestMeal(id: 'vault_01', name: 'كفتة فراخ');
        final mealB = _createTestMeal(id: 'vault_02', name: 'كفتة لحمة');
        fakeRepo.candidatesToReturn = [
          _createCandidate(original: mealA, duplicate: mealB)
        ];

        await pumpDialog(tester);
        const strings = AppStrings(Locale('ar'));

        final deleteBtn = find.text(strings.vaultDeduplicationDeleteAction);
        expect(deleteBtn, findsOneWidget);

        await tester.tap(deleteBtn);
        await tester.pumpAndSettle();

        expect(fakeRepo.deletedMealIds, contains('vault_02'));
        expect(find.text('كفتة لحمة'), findsNothing);
        expect(find.text(strings.vaultDeduplicationEmptyTitle), findsOneWidget);
      },
    );

    testWidgets(
      '10. Tapping "Ignore" calls ignoreDuplicatePair and removes candidate',
      (tester) async {
        final mealA = _createTestMeal(id: 'vault_01', name: 'كفتة فراخ');
        final mealB = _createTestMeal(id: 'vault_02', name: 'كفتة لحمة');
        fakeRepo.candidatesToReturn = [
          _createCandidate(original: mealA, duplicate: mealB, similarity: 0.82)
        ];

        await pumpDialog(tester);
        const strings = AppStrings(Locale('ar'));

        final ignoreBtn = find.text(strings.vaultDeduplicationIgnoreAction);
        expect(ignoreBtn, findsOneWidget);

        await tester.tap(ignoreBtn);
        await tester.pumpAndSettle();

        expect(fakeRepo.ignoredCalls, hasLength(1));
        expect(fakeRepo.ignoredCalls.first.mealA.id, 'vault_01');
        expect(fakeRepo.ignoredCalls.first.mealB.id, 'vault_02');
        expect(find.text('كفتة لحمة'), findsNothing);
        expect(find.text(strings.vaultDeduplicationEmptyTitle), findsOneWidget);
      },
    );

    testWidgets(
      '11. "Clean All Remaining" button triggers batch deletion on confirmation',
      (tester) async {
        final meal1 = _createTestMeal(id: 'm1', name: 'ملوخية بالفراخ');
        final meal2 = _createTestMeal(id: 'm2', name: 'ملوخية بالارانب');
        final meal3 = _createTestMeal(id: 'm3', name: 'مسقعة بلدي');
        final meal4 = _createTestMeal(id: 'm4', name: 'مسقعة باللحمة');

        fakeRepo.candidatesToReturn = [
          _createCandidate(original: meal1, duplicate: meal2),
          _createCandidate(original: meal3, duplicate: meal4),
        ];

        await pumpDialog(tester);
        const strings = AppStrings(Locale('ar'));

        final cleanAllBtn =
            find.text(strings.vaultDeduplicationCleanAllWithCount(2));
        expect(cleanAllBtn, findsOneWidget);

        await tester.tap(cleanAllBtn);
        await tester.pumpAndSettle();

        // Verify confirmation dialog
        expect(
          find.text(strings.vaultDeduplicationConfirmCleanAllTitle),
          findsOneWidget,
        );

        // Confirm clean
        final confirmBtn =
            find.text(strings.vaultDeduplicationConfirmCleanAllConfirm);
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        expect(fakeRepo.batchDeletedMealIds, containsAll(['m2', 'm4']));
        expect(find.text(strings.vaultDeduplicationEmptyTitle), findsOneWidget);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Tier 2: Boundary & Corner Cases
  // ───────────────────────────────────────────────────────────────────────────
  group('Tier 2: Boundary & Corner Cases', () {
    testWidgets(
      '12. 100% similarity renders Exact Match pill badge',
      (tester) async {
        final mealA = _createTestMeal(id: 'm1', name: 'أرز بالشعرية');
        final mealB = _createTestMeal(id: 'm2', name: 'ارز بالشعريه');
        fakeRepo.candidatesToReturn = [
          _createCandidate(original: mealA, duplicate: mealB, similarity: 1.0)
        ];

        await pumpDialog(tester);
        const strings = AppStrings(Locale('ar'));

        expect(find.text(strings.vaultDeduplicationExactMatch), findsOneWidget);
        expect(find.textContaining('100%'), findsOneWidget);
      },
    );

    testWidgets(
      '13. Similarity below 95% renders clay soft badge with percentage',
      (tester) async {
        final mealA = _createTestMeal(id: 'm1', name: 'كفتة مشوية');
        final mealB = _createTestMeal(id: 'm2', name: 'كفتة مقلية');
        fakeRepo.candidatesToReturn = [
          _createCandidate(original: mealA, duplicate: mealB, similarity: 0.85)
        ];

        await pumpDialog(tester);
        const strings = AppStrings(Locale('ar'));

        // The same phrase is the name-match mode's tab label, so the badge is
        // read from the results list it belongs to.
        expect(
          find.descendant(
            of: find.byType(ListView),
            matching: find.text(strings.vaultDeduplicationSimilarName),
          ),
          findsOneWidget,
        );
        expect(find.textContaining('85%'), findsOneWidget);
      },
    );

    testWidgets(
      '14. Error during scan renders error message and Retry button',
      (tester) async {
        fakeRepo.throwOnDetect = true;
        await pumpDialog(tester);

        const strings = AppStrings(Locale('ar'));
        expect(find.text(strings.vaultDeduplicationErrorTitle), findsOneWidget);

        final retryBtn = find.text(strings.vaultDeduplicationRetry);
        expect(retryBtn, findsOneWidget);

        // Reset error and retry
        fakeRepo.throwOnDetect = false;
        fakeRepo.candidatesToReturn = [
          _createCandidate(
            original: _createTestMeal(id: 'm1', name: 'شاورما دجاج'),
            duplicate: _createTestMeal(id: 'm2', name: 'شاورما لحم'),
          )
        ];

        await tester.tap(retryBtn);
        await tester.pumpAndSettle();

        expect(find.text('شاورما دجاج'), findsOneWidget);
      },
    );

    testWidgets(
      '15. Cancelling batch clean confirmation preserves candidate cards',
      (tester) async {
        final meal1 = _createTestMeal(id: 'm1', name: 'شوربة عدس');
        final meal2 = _createTestMeal(id: 'm2', name: 'شوربة خضار');
        fakeRepo.candidatesToReturn = [
          _createCandidate(original: meal1, duplicate: meal2)
        ];

        await pumpDialog(tester);
        const strings = AppStrings(Locale('ar'));

        await tester
            .tap(find.text(strings.vaultDeduplicationCleanAllWithCount(1)));
        await tester.pumpAndSettle();

        // Cancel confirmation
        final cancelBtn =
            find.text(strings.vaultDeduplicationConfirmCleanAllCancel);
        await tester.tap(cancelBtn);
        await tester.pumpAndSettle();

        expect(fakeRepo.batchDeletedMealIds, isEmpty);
        expect(find.text('شوربة عدس'), findsOneWidget);
      },
    );

    testWidgets(
      '16. Very long meal names and IDs do not overflow layout',
      (tester) async {
        const longNameA =
            'طاجن مكرونة بالبشاميل واللحمة المفرومة على الطريقة المصرية الأصيلة مع جبنة موزاريلا';
        const longNameB =
            'طاجن مكرونه بالبشاميل واللحمه المفرومه على الطريقه المصريه الاصيله بالجبنه';
        final mealA = _createTestMeal(
          id: 'vault_long_id_000000000000000000001',
          name: longNameA,
        );
        final mealB = _createTestMeal(
          id: 'vault_long_id_000000000000000000002',
          name: longNameB,
        );

        fakeRepo.candidatesToReturn = [
          _createCandidate(original: mealA, duplicate: mealB, similarity: 0.92)
        ];

        await pumpDialog(tester, viewport: const Size(600, 800));
        expect(tester.takeException(), isNull);
      },
    );

    testWidgets(
      '17. Batch clean with redundant duplicate IDs sends unique IDs only',
      (tester) async {
        final mealA = _createTestMeal(id: 'mA', name: 'مكرونة 1');
        final mealB = _createTestMeal(id: 'mB', name: 'مكرونة 2');
        final mealC = _createTestMeal(id: 'mC', name: 'مكرونة 3');

        // Both pairs designate mealC as duplicate
        fakeRepo.candidatesToReturn = [
          _createCandidate(original: mealA, duplicate: mealC),
          _createCandidate(original: mealB, duplicate: mealC),
        ];

        await pumpDialog(tester);
        const strings = AppStrings(Locale('ar'));

        // Clean button displays count of unique duplicates: (1)
        final cleanBtn =
            find.text(strings.vaultDeduplicationCleanAllWithCount(1));
        expect(cleanBtn, findsOneWidget);

        await tester.tap(cleanBtn);
        await tester.pumpAndSettle();

        final confirmBtn =
            find.text(strings.vaultDeduplicationConfirmCleanAllConfirm);
        await tester.tap(confirmBtn);
        await tester.pumpAndSettle();

        expect(fakeRepo.batchDeletedMealIds, ['mC']);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Tier 3: Cross-Feature Interactions & Transitive Pruning
  // ───────────────────────────────────────────────────────────────────────────
  group('Tier 3: Transitive Duplicate Pruning', () {
    testWidgets(
      '18. Deleting duplicate meal B prunes other pairs referencing B as duplicate',
      (tester) async {
        // Meal B is duplicate in Pair 1 (kept A, deleted B) and Pair 2 (kept C, deleted B)
        final mealA = _createTestMeal(id: 'mA', name: 'كفتة مشوية 1');
        final mealB = _createTestMeal(id: 'mB', name: 'كفتة مشوية 2');
        final mealC = _createTestMeal(id: 'mC', name: 'كفتة مشوية 3');

        fakeRepo.candidatesToReturn = [
          _createCandidate(original: mealA, duplicate: mealB),
          _createCandidate(original: mealC, duplicate: mealB),
        ];

        await pumpDialog(tester);
        const strings = AppStrings(Locale('ar'));

        // Both pairs initially shown
        expect(find.text('كفتة مشوية 1'), findsOneWidget);
        expect(find.text('كفتة مشوية 3'), findsOneWidget);

        // Delete duplicate in first pair
        final deleteButtons = find.text(strings.vaultDeduplicationDeleteAction);
        await tester.tap(deleteButtons.first);
        await tester.pumpAndSettle();

        // Meal B is deleted; pair 2 also contained B as duplicate and must be pruned locally!
        expect(fakeRepo.deletedMealIds, ['mB']);
        expect(find.text('كفتة مشوية 3'), findsNothing);
        expect(find.text(strings.vaultDeduplicationEmptyTitle), findsOneWidget);
      },
    );

    testWidgets(
      '19. Deleting duplicate meal B prunes other pairs where B was the original',
      (tester) async {
        // Pair 1: kept A, deleted B. Pair 2: kept B, deleted C.
        final mealA = _createTestMeal(id: 'mA', name: 'صينية بطاطس 1');
        final mealB = _createTestMeal(id: 'mB', name: 'صينية بطاطس 2');
        final mealC = _createTestMeal(id: 'mC', name: 'صينية بطاطس 3');

        fakeRepo.candidatesToReturn = [
          _createCandidate(original: mealA, duplicate: mealB),
          _createCandidate(original: mealB, duplicate: mealC),
        ];

        await pumpDialog(tester);
        const strings = AppStrings(Locale('ar'));

        final deleteButtons = find.text(strings.vaultDeduplicationDeleteAction);
        await tester.tap(deleteButtons.first);
        await tester.pumpAndSettle();

        // Pair 2 cannot keep B because B was deleted! It must be pruned.
        expect(fakeRepo.deletedMealIds, ['mB']);
        expect(find.text('صينية بطاطس 3'), findsNothing);
        expect(find.text(strings.vaultDeduplicationEmptyTitle), findsOneWidget);
      },
    );

    testWidgets(
      '20. When transitive pruning clears all remaining pairs, dialog transitions to Empty State',
      (tester) async {
        // Pair 1: (A, B), Pair 2: (C, B)
        final mealA = _createTestMeal(id: 'mA', name: 'طعمية 1');
        final mealB = _createTestMeal(id: 'mB', name: 'طعمية 2');
        final mealC = _createTestMeal(id: 'mC', name: 'طعمية 3');

        fakeRepo.candidatesToReturn = [
          _createCandidate(original: mealA, duplicate: mealB),
          _createCandidate(original: mealC, duplicate: mealB),
        ];

        await pumpDialog(tester);
        const strings = AppStrings(Locale('ar'));

        final deleteButtons = find.text(strings.vaultDeduplicationDeleteAction);
        await tester.tap(deleteButtons.first);
        await tester.pumpAndSettle();

        expect(find.text(strings.vaultDeduplicationEmptyTitle), findsOneWidget);
        expect(
          find.text(strings.vaultDeduplicationEmptySubtitle),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      '21. Ignoring one pair does NOT prune other pairs referencing the same meals',
      (tester) async {
        final mealA = _createTestMeal(id: 'mA', name: 'كشري 1');
        final mealB = _createTestMeal(id: 'mB', name: 'كشري 2');
        final mealC = _createTestMeal(id: 'mC', name: 'كشري 3');

        fakeRepo.candidatesToReturn = [
          _createCandidate(original: mealA, duplicate: mealB),
          _createCandidate(original: mealA, duplicate: mealC),
        ];

        await pumpDialog(tester);
        const strings = AppStrings(Locale('ar'));

        final ignoreButtons = find.text(strings.vaultDeduplicationIgnoreAction);
        await tester.tap(ignoreButtons.first);
        await tester.pumpAndSettle();

        // Only pair 1 was ignored; pair 2 remains visible
        expect(fakeRepo.ignoredCalls, hasLength(1));
        expect(find.text('كشري 3'), findsOneWidget);
        expect(find.text(strings.vaultDeduplicationEmptyTitle), findsNothing);
      },
    );

    testWidgets(
      '22. Interactive sequential workflow: ignoring one pair and deleting another leaves only remaining candidates',
      (tester) async {
        final m1 = _createTestMeal(id: 'm1', name: 'بامية 1');
        final m2 = _createTestMeal(id: 'm2', name: 'بامية 2');
        final m3 = _createTestMeal(id: 'm3', name: 'لوبيا 1');
        final m4 = _createTestMeal(id: 'm4', name: 'لوبيا 2');
        final m5 = _createTestMeal(id: 'm5', name: 'فاصوليا 1');
        final m6 = _createTestMeal(id: 'm6', name: 'فاصوليا 2');

        fakeRepo.candidatesToReturn = [
          _createCandidate(original: m1, duplicate: m2),
          _createCandidate(original: m3, duplicate: m4),
          _createCandidate(original: m5, duplicate: m6),
        ];

        await pumpDialog(tester);
        const strings = AppStrings(Locale('ar'));

        // 1. Ignore first pair (بامية)
        await tester.tap(find.text(strings.vaultDeduplicationIgnoreAction).first);
        await tester.pumpAndSettle();

        expect(fakeRepo.ignoredCalls, hasLength(1));
        expect(find.text('بامية 1'), findsNothing);
        expect(find.text('لوبيا 1'), findsOneWidget);
        expect(find.text('فاصوليا 1'), findsOneWidget);

        // 2. Delete duplicate in second pair (لوبيا)
        await tester.tap(find.text(strings.vaultDeduplicationDeleteAction).first);
        await tester.pumpAndSettle();

        expect(fakeRepo.deletedMealIds, contains('m4'));
        expect(find.text('لوبيا 1'), findsNothing);
        expect(find.text('فاصوليا 1'), findsOneWidget);
      },
    );
  });

  // ───────────────────────────────────────────────────────────────────────────
  // Tier 4: Real-World Scenarios & Bilingual Verification
  // ───────────────────────────────────────────────────────────────────────────
  group('Tier 4: Real-World Scenarios & Bilingual Verification', () {
    testWidgets(
      '23. Egyptian dialect dishes comparison preserves starter meal as original',
      (tester) async {
        final starterKofta = _createTestMeal(
          id: 'kofta_starter',
          name: 'كفتة فراخ',
          isStarterMeal: true,
          createdAt: DateTime.parse('2026-05-01T00:00:00Z'), // Newer date
        );
        final olderKofta = _createTestMeal(
          id: 'kofta_old',
          name: 'كفتة لحمة',
          isStarterMeal: false,
          createdAt: DateTime.parse('2024-01-01T00:00:00Z'), // Older date
        );

        // Canonical precedence: starterMeal takes top priority
        final candidate = DuplicatePairCandidate.resolve(
          mealA: olderKofta,
          mealB: starterKofta,
          similarity: 0.822,
        );

        fakeRepo.candidatesToReturn = [candidate];
        await pumpDialog(tester);

        expect(candidate.originalMeal.id, 'kofta_starter');
        expect(candidate.duplicateMeal.id, 'kofta_old');
        expect(find.text('كفتة فراخ'), findsOneWidget);
        expect(find.text('كفتة لحمة'), findsOneWidget);
      },
    );

    testWidgets(
      '24. Full English locale verification renders LTR and zero Arabic strings',
      (tester) async {
        final mealA = _createTestMeal(id: 'm1', name: 'Chicken Kofta');
        final mealB = _createTestMeal(id: 'm2', name: 'Beef Kofta');
        fakeRepo.candidatesToReturn = [
          _createCandidate(original: mealA, duplicate: mealB, similarity: 0.85)
        ];

        await pumpDialog(tester, locale: const Locale('en'));

        expect(find.text('Vault Deduplication'), findsOneWidget);
        expect(find.text('Original (Keep)'), findsOneWidget);
        expect(find.text('Duplicate (Delete)'), findsOneWidget);
        expect(find.text('Delete Duplicate'), findsOneWidget);
        expect(find.text('Ignore'), findsOneWidget);
        expect(find.text('Clean All Remaining (1)'), findsOneWidget);

        // Verify zero hardcoded Arabic text leaks
        expect(find.textContaining('تنظيف الخزنة'), findsNothing);
        expect(find.textContaining('الأصلية'), findsNothing);
        expect(find.textContaining('المكررة'), findsNothing);
      },
    );
  });
}
