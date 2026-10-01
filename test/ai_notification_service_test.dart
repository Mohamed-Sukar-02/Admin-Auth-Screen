import 'package:daily_meal/features/admin/data/ai_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AiNotificationService service;

  setUp(() {
    service = AiNotificationService();
  });

  group('R3: Discount Regex & Smart Template (100% Support)', () {
    test('captures 100% discount fully as "100" without truncating to "00"', () {
      final draft = service.generateSmartTemplate(
        'عرض خصم 100% بمناسبة الافتتاح',
        0,
      );

      expect(draft, isNotNull);
      expect(draft!.titleAr, contains('100%'));
      expect(draft.titleAr, isNot(contains('خصم 00%')));
      expect(draft.messageAr, contains('100%'));
      expect(draft.titleEn, contains('100%'));
    });

    test('captures 100% discount with Eastern Arabic numerals ١٠٠٪ fully', () {
      final draft = service.generateSmartTemplate(
        'عرض خصم ١٠٠٪ لفترة محدودة',
        0,
      );

      expect(draft, isNotNull);
      expect(draft!.titleAr, contains('١٠٠%'));
      expect(draft.titleAr, isNot(contains('خصم ٠٠%')));
      expect(draft.messageAr, contains('١٠٠%'));
    });

    test('captures 1-digit and 2-digit discounts accurately', () {
      final draft5 = service.generateSmartTemplate('خصم 5% فقط', 0);
      expect(draft5, isNotNull);
      expect(draft5!.titleAr, contains('5%'));

      final draft50 = service.generateSmartTemplate('خصم 50% على كل الأكلات', 0);
      expect(draft50, isNotNull);
      expect(draft50!.titleAr, contains('50%'));

      final draftArabic50 = service.generateSmartTemplate('خصم ٥٠٪ على الأصناف', 0);
      expect(draftArabic50, isNotNull);
      expect(draftArabic50!.titleAr, contains('٥٠%'));

      final draftArabic5 = service.generateSmartTemplate('خصم ٥٪ للتجربة', 0);
      expect(draftArabic5, isNotNull);
      expect(draftArabic5!.titleAr, contains('٥%'));
    });

    test('handles whitespace variations before percent symbol', () {
      final draftSpace = service.generateSmartTemplate('خصم 100 % على البيتزا', 0);
      expect(draftSpace, isNotNull);
      expect(draftSpace!.titleAr, contains('100%'));
    });

    test('preserves 100% discount across all template variants (0, 1, 2)', () {
      for (int v = 0; v < 3; v++) {
        final draft = service.generateSmartTemplate('عرض خصم 100% للكل', v);
        expect(draft, isNotNull);
        expect(draft!.titleAr, contains('100%'), reason: 'Variant $v should contain 100% in title');
        expect(draft.titleAr, isNot(contains('خصم 00%')), reason: 'Variant $v must not truncate 100% to 00%');
      }
    });

    test('generic offer without discount number produces valid copy without percentage', () {
      final draft = service.generateSmartTemplate('عرض خاص على كل الأصناف', 0);
      expect(draft, isNotNull);
      expect(draft!.titleAr, isNot(contains('%')));
      expect(draft.titleAr, isNot(contains('null')));
    });
  });

  group('R2: Dynamic Suggestions JSON Parsing', () {
    test('parses JSON Object containing "notifications" array format correctly', () {
      const response = '''
      {
        "notifications": [
          {"label": "اقتراح كشري", "prompt": "إشعار بيقترح على المستخدمين يجربوا وصفة الكشري للغدا النهاردة"},
          {"label": "تذكير رمضان", "prompt": "فكرهم بلمة العيلة على الفطار في رمضان"}
        ]
      }
      ''';

      final result = AiNotificationService.parseDynamicSuggestions(response);
      expect(result, hasLength(2));
      expect(result[0]['label'], 'اقتراح كشري');
      expect(result[0]['prompt'], contains('الكشري'));
      expect(result[1]['label'], 'تذكير رمضان');
      expect(result[1]['prompt'], contains('العيلة'));
    });

    test('maintains backward compatibility with bare JSON Array format', () {
      const legacyResponse = '''
      [
        {"label": "كفتة مشوية", "prompt": "اقتراح كفتة مشوية على الفحم"}
      ]
      ''';

      final result = AiNotificationService.parseDynamicSuggestions(legacyResponse);
      expect(result, hasLength(1));
      expect(result[0]['label'], 'كفتة مشوية');
      expect(result[0]['prompt'], 'اقتراح كفتة مشوية على الفحم');
    });

    test('handles alternative container keys ("suggestions" and "ideas")', () {
      const suggestionsJson = '''
      {
        "suggestions": [
          {"label": "مسقعة بلدي", "prompt": "طاجن مسقعة باللحمة المفرومة"}
        ]
      }
      ''';

      final res1 = AiNotificationService.parseDynamicSuggestions(suggestionsJson);
      expect(res1, hasLength(1));
      expect(res1[0]['label'], 'مسقعة بلدي');

      const ideasJson = '''
      {
        "ideas": [
          {"label": "ملوخية سخنة", "prompt": "ملوخية بالأرانب وريحتها تجنن"}
        ]
      }
      ''';

      final res2 = AiNotificationService.parseDynamicSuggestions(ideasJson);
      expect(res2, hasLength(1));
      expect(res2[0]['label'], 'ملوخية سخنة');
    });

    test('falls back to the first available List value in an arbitrary JSON Object', () {
      const genericObjectJson = '''
      {
        "customItems": [
          {"label": "حواوشي", "prompt": "رغيف حواوشي سخن"}
        ]
      }
      ''';

      final result = AiNotificationService.parseDynamicSuggestions(genericObjectJson);
      expect(result, hasLength(1));
      expect(result[0]['label'], 'حواوشي');
    });

    test('cleans markdown code fences (```json and ```) before parsing', () {
      const markdownWrapped = '''
      ```json
      {
        "notifications": [
          {"label": "شاورما", "prompt": "ساندوتش شاورما فراخ مع تومية"}
        ]
      }
      ```
      ''';

      final result = AiNotificationService.parseDynamicSuggestions(markdownWrapped);
      expect(result, hasLength(1));
      expect(result[0]['label'], 'شاورما');
    });

    test('sanitizes nulls, trims whitespace, and skips corrupt entries', () {
      const dirtyJson = '''
      {
        "notifications": [
          {"label": "  طعمية سخنة  ", "prompt": "  فطار الصبح  "},
          {"label": null, "prompt": "إشعار بدون عنوان"},
          {"label": "عنوان بدون وصف", "prompt": null},
          {"label": "", "prompt": ""},
          "invalid string item",
          42
        ]
      }
      ''';

      final result = AiNotificationService.parseDynamicSuggestions(dirtyJson);
      expect(result, hasLength(3));
      expect(result[0]['label'], 'طعمية سخنة');
      expect(result[0]['prompt'], 'فطار الصبح');
      expect(result[1]['label'], '');
      expect(result[1]['prompt'], 'إشعار بدون عنوان');
      expect(result[2]['label'], 'عنوان بدون وصف');
      expect(result[2]['prompt'], '');
    });

    test('returns empty list gracefully on invalid input without throwing TypeError', () {
      expect(AiNotificationService.parseDynamicSuggestions(''), isEmpty);
      expect(AiNotificationService.parseDynamicSuggestions('   '), isEmpty);
      expect(AiNotificationService.parseDynamicSuggestions('{not a json}'), isEmpty);
      expect(AiNotificationService.parseDynamicSuggestions('{"status": "error"}'), isEmpty);
      expect(AiNotificationService.parseDynamicSuggestions('"just a string"'), isEmpty);
      expect(AiNotificationService.parseDynamicSuggestions('12345'), isEmpty);
      expect(AiNotificationService.parseDynamicSuggestions('null'), isEmpty);
    });

    test('backward-compatible parseSuggestions alias produces identical results', () {
      const json = '{"notifications": [{"label": "كشري", "prompt": "طبق كشري"}]}';
      final viaAlias = AiNotificationService.parseSuggestions(json);
      final direct = AiNotificationService.parseDynamicSuggestions(json);
      expect(viaAlias, equals(direct));
    });
  });
}
