import 'package:daily_meal/core/localization/app_strings.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AppStrings Deduplication Localization Tests', () {
    const arStrings = AppStrings(Locale('ar'));
    const enStrings = AppStrings(Locale('en'));

    test('All getters return non-empty strings in Arabic and English', () {
      expect(arStrings.vaultDeduplicationTitle, isNotEmpty);
      expect(enStrings.vaultDeduplicationTitle, isNotEmpty);
      expect(arStrings.vaultDeduplicationSubtitle, isNotEmpty);
      expect(enStrings.vaultDeduplicationSubtitle, isNotEmpty);
      expect(arStrings.vaultDeduplicationOverviewButton, isNotEmpty);
      expect(enStrings.vaultDeduplicationOverviewButton, isNotEmpty);
      expect(arStrings.vaultDeduplicationBannerWarning, isNotEmpty);
      expect(enStrings.vaultDeduplicationBannerWarning, isNotEmpty);
      expect(arStrings.vaultDeduplicationDeleteAction, isNotEmpty);
      expect(enStrings.vaultDeduplicationDeleteAction, isNotEmpty);
      expect(arStrings.vaultDeduplicationIgnoreAction, isNotEmpty);
      expect(enStrings.vaultDeduplicationIgnoreAction, isNotEmpty);
      expect(arStrings.vaultDeduplicationCleanAll, isNotEmpty);
      expect(enStrings.vaultDeduplicationCleanAll, isNotEmpty);
      expect(arStrings.vaultDeduplicationEmptyTitle, isNotEmpty);
      expect(enStrings.vaultDeduplicationEmptyTitle, isNotEmpty);
      expect(arStrings.vaultDeduplicationSettingsTileTitle, isNotEmpty);
      expect(enStrings.vaultDeduplicationSettingsTileTitle, isNotEmpty);
      expect(arStrings.vaultDeduplicationSettingsTileSubtitle, isNotEmpty);
      expect(enStrings.vaultDeduplicationSettingsTileSubtitle, isNotEmpty);
      expect(arStrings.vaultDeduplicationCleanButton, isNotEmpty);
      expect(enStrings.vaultDeduplicationCleanButton, isNotEmpty);
      expect(arStrings.vaultOperationsSection, isNotEmpty);
      expect(enStrings.vaultOperationsSection, isNotEmpty);
    });

    test('vaultDeduplicationPairsFound handles Arabic grammatical numbers', () {
      expect(
        arStrings.vaultDeduplicationPairsFound(0),
        'لم يتم العثور على أزواج متشابهة',
      );
      expect(
        arStrings.vaultDeduplicationPairsFound(1),
        'تم اكتشاف زوج متشابه واحد',
      );
      expect(
        arStrings.vaultDeduplicationPairsFound(2),
        'تم اكتشاف زوجين متشابهين',
      );
      expect(
        arStrings.vaultDeduplicationPairsFound(5),
        'تم اكتشاف 5 أزواج متشابهة',
      );
      expect(
        arStrings.vaultDeduplicationPairsFound(15),
        'تم اكتشاف 15 زوجاً متشابهاً',
      );

      expect(
        enStrings.vaultDeduplicationPairsFound(1),
        '1 potential duplicate pair found',
      );
      expect(
        enStrings.vaultDeduplicationPairsFound(3),
        '3 potential duplicate pairs found',
      );
    });

    test('vaultDeduplicationConfirmCleanAllMessage handles Arabic meal plurals',
        () {
      expect(
        arStrings.vaultDeduplicationConfirmCleanAllMessage(1),
        contains('وجبة مكررة واحدة'),
      );
      expect(
        arStrings.vaultDeduplicationConfirmCleanAllMessage(2),
        contains('وجبتين مكررتين'),
      );
      expect(
        arStrings.vaultDeduplicationConfirmCleanAllMessage(4),
        contains('4 وجبات مكررة'),
      );
      expect(
        arStrings.vaultDeduplicationConfirmCleanAllMessage(12),
        contains('12 وجبة مكررة'),
      );

      expect(
        enStrings.vaultDeduplicationConfirmCleanAllMessage(1),
        contains('1 duplicate meal'),
      );
      expect(
        enStrings.vaultDeduplicationConfirmCleanAllMessage(3),
        contains('3 duplicate meals'),
      );
    });

    test('vaultDeduplicationAllCleanedSuccess handles Arabic meal plurals', () {
      expect(
        arStrings.vaultDeduplicationAllCleanedSuccess(1),
        'تم بنجاح حذف وجبة مكررة واحدة',
      );
      expect(
        arStrings.vaultDeduplicationAllCleanedSuccess(2),
        'تم بنجاح حذف وجبتين مكررتين',
      );
      expect(
        arStrings.vaultDeduplicationAllCleanedSuccess(3),
        'تم بنجاح تنظيف وحذف 3 وجبات مكررة',
      );
      expect(
        arStrings.vaultDeduplicationAllCleanedSuccess(11),
        'تم بنجاح تنظيف وحذف 11 وجبة مكررة',
      );

      expect(
        enStrings.vaultDeduplicationAllCleanedSuccess(1),
        'Successfully deleted 1 duplicate meal',
      );
      expect(
        enStrings.vaultDeduplicationAllCleanedSuccess(2),
        'Successfully deleted 2 duplicate meals',
      );
    });

    test('Parameterized formatters format names, IDs, dates, and percentages',
        () {
      expect(arStrings.vaultDeduplicationMealId('meal_123'), 'المعرّف: meal_123');
      expect(enStrings.vaultDeduplicationMealId('meal_123'), 'ID: meal_123');

      expect(arStrings.vaultDeduplicationSimilarity(85), 'تطابق 85%');
      expect(enStrings.vaultDeduplicationSimilarity(85), '85% Match');

      expect(
        arStrings.vaultDeduplicationDeletedSuccess('كفتة'),
        contains('كفتة'),
      );
      expect(
        enStrings.vaultDeduplicationDeletedSuccess('Kofta'),
        contains('Kofta'),
      );

      expect(
        arStrings.vaultDeduplicationIgnoredSuccess('كفتة', 'كباب'),
        contains('كفتة'),
      );
      expect(
        enStrings.vaultDeduplicationIgnoredSuccess('Kofta', 'Kebab'),
        contains('Kofta'),
      );
    });
  });
}
