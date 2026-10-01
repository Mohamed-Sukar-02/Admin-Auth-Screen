import 'package:daily_meal/features/admin/data/ai_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AiNotificationService service;

  setUp(() {
    service = AiNotificationService();
  });

  group('Adversarial Test Suite — JSON Payload Stress Testing', () {
    test('Scenario 1: Completely empty or whitespace-only inputs', () {
      expect(AiNotificationService.parseDynamicSuggestions(''), isEmpty);
      expect(AiNotificationService.parseDynamicSuggestions('   '), isEmpty);
      expect(AiNotificationService.parseDynamicSuggestions('\n\t\r  \n'), isEmpty);
    });

    test('Scenario 2: HTML error bodies or proxy responses (e.g., 502 Bad Gateway)', () {
      const html502 = '''
      <!DOCTYPE html>
      <html>
        <head><title>502 Bad Gateway</title></head>
        <body><center><h1>502 Bad Gateway</h1></center><hr><center>cloudflare</center></body>
      </html>
      ''';
      expect(AiNotificationService.parseDynamicSuggestions(html502), isEmpty);

      const html504 = '<html><body><h1>504 Gateway Timeout</h1></body></html>';
      expect(AiNotificationService.parseDynamicSuggestions(html504), isEmpty);
    });

    test('Scenario 3: Plain text non-JSON error messages from backend or AI models', () {
      expect(
        AiNotificationService.parseDynamicSuggestions('Error: Rate limit exceeded. Try again in 20s.'),
        isEmpty,
      );
      expect(
        AiNotificationService.parseDynamicSuggestions('The model is currently overloaded with other requests.'),
        isEmpty,
      );
      expect(
        AiNotificationService.parseDynamicSuggestions('Internal Server Error (500)'),
        isEmpty,
      );
    });

    test('Scenario 4: Truncated or syntactically invalid JSON', () {
      expect(
        AiNotificationService.parseDynamicSuggestions('{"notifications": [{"label": "كشري", "prompt": "إشعار'),
        isEmpty,
      );
      expect(
        AiNotificationService.parseDynamicSuggestions('{"notifications": [}'),
        isEmpty,
      );
      expect(
        AiNotificationService.parseDynamicSuggestions('{"notifications": [{"label": "كشري", "prompt": "وصف"}'),
        isEmpty,
      );
      expect(
        AiNotificationService.parseDynamicSuggestions('{"notifications": [,]'),
        isEmpty,
      );
    });

    test('Scenario 5: JSON primitives at the root level', () {
      expect(AiNotificationService.parseDynamicSuggestions('"just a string"'), isEmpty);
      expect(AiNotificationService.parseDynamicSuggestions('123456789'), isEmpty);
      expect(AiNotificationService.parseDynamicSuggestions('3.14159'), isEmpty);
      expect(AiNotificationService.parseDynamicSuggestions('true'), isEmpty);
      expect(AiNotificationService.parseDynamicSuggestions('false'), isEmpty);
      expect(AiNotificationService.parseDynamicSuggestions('null'), isEmpty);
    });

    test('Scenario 6: Empty root objects and maps with no lists', () {
      expect(AiNotificationService.parseDynamicSuggestions('{}'), isEmpty);
      expect(
        AiNotificationService.parseDynamicSuggestions('{"status": "success", "code": 200, "message": "OK"}'),
        isEmpty,
      );
      expect(
        AiNotificationService.parseDynamicSuggestions('{"data": null, "error": null}'),
        isEmpty,
      );
    });

    test('Scenario 7: Root object with empty notifications list', () {
      expect(
        AiNotificationService.parseDynamicSuggestions('{"notifications": []}'),
        isEmpty,
      );
      expect(
        AiNotificationService.parseDynamicSuggestions('{"suggestions": []}'),
        isEmpty,
      );
      expect(
        AiNotificationService.parseDynamicSuggestions('{"ideas": []}'),
        isEmpty,
      );
      expect(
        AiNotificationService.parseDynamicSuggestions('{"anyList": []}'),
        isEmpty,
      );
    });

    test('Scenario 8: Missing keys, null values, and whitespace-only fields', () {
      const payload = '''
      {
        "notifications": [
          {"label": null, "prompt": null},
          {"label": "", "prompt": ""},
          {"label": "   ", "prompt": "   "},
          {"label": "\\t\\n  ", "prompt": "  \\r\\n "},
          {},
          {"otherKey": "no label or prompt"},
          {"label": "صالح فقط", "prompt": ""},
          {"label": "", "prompt": "برومبت صالح فقط"}
        ]
      }
      ''';

      final result = AiNotificationService.parseDynamicSuggestions(payload);
      // Only the last two items have at least one non-empty field after trimming
      expect(result, hasLength(2));
      expect(result[0]['label'], 'صالح فقط');
      expect(result[0]['prompt'], '');
      expect(result[1]['label'], '');
      expect(result[1]['prompt'], 'برومبت صالح فقط');
    });

    test('Scenario 9: Corrupted array containing non-map elements', () {
      const payload = '''
      {
        "notifications": [
          null,
          100,
          99.9,
          true,
          false,
          "random string in array",
          ["nested", "array"],
          {"label": "طعمية سخنة", "prompt": "فطار مصري أصيل"}
        ]
      }
      ''';

      final result = AiNotificationService.parseDynamicSuggestions(payload);
      expect(result, hasLength(1));
      expect(result[0]['label'], 'طعمية سخنة');
      expect(result[0]['prompt'], 'فطار مصري أصيل');
    });

    test('Scenario 10: Non-string primitive values for label and prompt', () {
      const payload = '''
      {
        "notifications": [
          {"label": 12345, "prompt": 67890},
          {"label": true, "prompt": false},
          {"label": {"title": "nested"}, "prompt": ["item1", "item2"]}
        ]
      }
      ''';

      final result = AiNotificationService.parseDynamicSuggestions(payload);
      expect(result, hasLength(3));
      expect(result[0]['label'], '12345');
      expect(result[0]['prompt'], '67890');
      expect(result[1]['label'], 'true');
      expect(result[1]['prompt'], 'false');
      expect(result[2]['label'], '{title: nested}');
      expect(result[2]['prompt'], '[item1, item2]');
    });

    test('Scenario 11: Deeply nested objects without direct List in root', () {
      // When a model returns wrapped structure like {"data": {"notifications": [...]}}
      const deeplyNested = '''
      {
        "data": {
          "notifications": [
            {"label": "ملوخية", "prompt": "ملوخية بالأرانب"}
          ]
        }
      }
      ''';

      // The parser looks at root level keys and root level List values.
      // Deeply nested Map without root List should gracefully return empty without throwing!
      final result = AiNotificationService.parseDynamicSuggestions(deeplyNested);
      expect(result, isEmpty);
    });

    test('Scenario 12: Markdown code block formatting edge cases', () {
      // 12a. Code block with 'json' tag and internal whitespace
      const wrapped1 = '```json\n  {"notifications": [{"label": "كفتة", "prompt": "كفتة مشوية"}]}  \n```';
      final res1 = AiNotificationService.parseDynamicSuggestions(wrapped1);
      expect(res1, hasLength(1));
      expect(res1[0]['label'], 'كفتة');

      // 12b. Code block without language tag
      const wrapped2 = '```\n{"notifications": [{"label": "حواوشي", "prompt": "حواوشي بلدي"}]}\n```';
      final res2 = AiNotificationService.parseDynamicSuggestions(wrapped2);
      expect(res2, hasLength(1));
      expect(res2[0]['label'], 'حواوشي');

      // 12c. Markdown code block surrounded by external conversational text:
      // Note: LLMs often output "Here are the suggestions: ```json ... ``` Enjoy!"
      const conversational = '''
      Here are the 3 notification ideas you requested:
      ```json
      {
        "notifications": [
          {"label": "بسبوسة", "prompt": "بسبوسة بالمكسرات"}
        ]
      }
      ```
      Let me know if you need more variations!
      ''';
      // Verifying that conversational markdown does not throw unhandled exception
      final res3 = AiNotificationService.parseDynamicSuggestions(conversational);
      // When external text is present, jsonDecode will fail on the prose,
      // and parseDynamicSuggestions MUST safely catch and return [] without crashing.
      expect(res3, isA<List<Map<String, String>>>());
    });

    test('Scenario 13: Unicode, Tashkeel (diacritics), and Emoji preservation in suggestions', () {
      const unicodePayload = '''
      {
        "notifications": [
          {"label": "أَكْلَةُ اليَوْمِ", "prompt": "جَرِّبِ الكُشَرِيَّ المَصْرِيَّ بِالدَّقَّةِ وَالشَّطَّةِ 🍲"},
          {"label": "🔥 عرض خاص", "prompt": "خصم 50% على كل الوصفات 🎉"}
        ]
      }
      ''';

      final result = AiNotificationService.parseDynamicSuggestions(unicodePayload);
      expect(result, hasLength(2));
      expect(result[0]['label'], 'أَكْلَةُ اليَوْمِ');
      expect(result[0]['prompt'], contains('🍲'));
      expect(result[1]['label'], '🔥 عرض خاص');
      expect(result[1]['prompt'], contains('🎉'));
    });

    test('Scenario 14: SQL / Script injection payloads parsed safely as plain strings', () {
      const injectionPayload = '''
      {
        "notifications": [
          {"label": "<script>alert('xss')</script>", "prompt": "'; DROP TABLE meals;--"},
          {"label": "SELECT * FROM users WHERE '1'='1'", "prompt": "\${eval(process.exit(1))}"}
        ]
      }
      ''';

      final result = AiNotificationService.parseDynamicSuggestions(injectionPayload);
      expect(result, hasLength(2));
      expect(result[0]['label'], "<script>alert('xss')</script>");
      expect(result[0]['prompt'], "'; DROP TABLE meals;--");
      expect(result[1]['label'], "SELECT * FROM users WHERE '1'='1'");
    });

    test('Scenario 15: High-volume stress test (500 items in notifications list)', () {
      final buffer = StringBuffer();
      buffer.write('{"notifications": [');
      for (int i = 0; i < 500; i++) {
        if (i > 0) buffer.write(',');
        buffer.write('{"label": "وجبة $i", "prompt": "وصف الوجبة رقم $i"}');
      }
      buffer.write(']}');

      final stopwatch = Stopwatch()..start();
      final result = AiNotificationService.parseDynamicSuggestions(buffer.toString());
      stopwatch.stop();

      expect(result, hasLength(500));
      expect(result.first['label'], 'وجبة 0');
      expect(result.last['label'], 'وجبة 499');
      expect(stopwatch.elapsedMilliseconds, lessThan(1000),
          reason: 'Parsing 500 suggestions must complete under 1 second');
    });
  });

  group('Adversarial Test Suite — Extreme Discount Strings & Regex Boundary Tests', () {
    test('Scenario 16: "خصم 100% الآن" regex extraction and template output', () {
      const input = 'خصم 100% الآن';
      final isolated00 = RegExp(r'(^|[^\d])00%');
      for (int v = 0; v < 3; v++) {
        final draft = service.generateSmartTemplate(input, v);
        expect(draft, isNotNull, reason: 'Variant $v should recognize offer and generate draft');
        expect(draft!.titleAr, contains('100%'));
        expect(draft.titleAr, isNot(matches(isolated00)));
        expect(draft.messageAr, contains('100%'));
        expect(draft.messageAr, isNot(matches(isolated00)));
      }
    });

    test('Scenario 17: "خصم ١٠٠٪ لفترة محدودة" (Eastern Arabic numerals) extraction and template', () {
      const input = 'خصم ١٠٠٪ لفترة محدودة';
      final isolatedArabic00 = RegExp(r'(^|[^٠-٩])٠٠%');
      for (int v = 0; v < 3; v++) {
        final draft = service.generateSmartTemplate(input, v);
        expect(draft, isNotNull, reason: 'Variant $v should generate draft for Eastern Arabic discount');
        expect(draft!.titleAr, contains('١٠٠%'));
        expect(draft.titleAr, isNot(matches(isolatedArabic00)));
        expect(draft.messageAr, contains('١٠٠%'));
      }
    });

    test('Scenario 18: "خصم 0%" boundary condition', () {
      const input = 'خصم 0% لفترة محدودة';
      final draft = service.generateSmartTemplate(input, 0);
      expect(draft, isNotNull);
      expect(draft!.titleAr, contains('0%'));
      expect(draft.messageAr, contains('0%'));
    });

    test('Scenario 19: "خصم 99%" two-digit boundary condition', () {
      const input = 'عرض خصم 99% لكل المستخدمين';
      final draft = service.generateSmartTemplate(input, 0);
      expect(draft, isNotNull);
      expect(draft!.titleAr, contains('99%'));
      expect(draft.messageAr, contains('99%'));
    });

    test('Scenario 20: Spacing variations between number and percentage ("تخفيض 100 %" & "خصم 100 %")', () {
      final isolated00 = RegExp(r'(^|[^\d])00%');
      // When combined with offer trigger keyword:
      const input1 = 'عرض تخفيض 100 % الآن';
      final draft1 = service.generateSmartTemplate(input1, 0);
      expect(draft1, isNotNull);
      expect(draft1!.titleAr, contains('100%'));
      expect(draft1.titleAr, isNot(matches(isolated00)));

      const input2 = 'خصم 100  % كبير';
      final draft2 = service.generateSmartTemplate(input2, 0);
      expect(draft2, isNotNull);
      expect(draft2!.titleAr, contains('100%'));
    });

    test('Scenario 21: "وفّر حتى 100% اليوم" with and without offer keyword triggers', () {
      final isolated00 = RegExp(r'(^|[^\d])00%');
      // Without offer keyword 'عرض' or 'خصم', template returns null (unrecognized intent)
      const inputWithoutOfferKeyword = 'وفّر حتى 100% اليوم';
      final draftWithout = service.generateSmartTemplate(inputWithoutOfferKeyword, 0);
      // Intentionally verify behavior: returns null because 'وفّر' alone does not match _offer
      expect(draftWithout, isNull);

      // When 'عرض' is prefixed to indicate offer intent:
      const inputWithOfferKeyword = 'عرض وفّر حتى 100% اليوم';
      final draftWith = service.generateSmartTemplate(inputWithOfferKeyword, 0);
      expect(draftWith, isNotNull);
      expect(draftWith!.titleAr, contains('100%'));
      expect(draftWith.titleAr, isNot(matches(isolated00)));
    });

    test('Scenario 22: "تخفيض 100 %" with and without offer keyword triggers', () {
      final isolated00 = RegExp(r'(^|[^\d])00%');
      // Without offer keyword 'عرض' or 'خصم'
      const inputWithout = 'تخفيض 100 %';
      final draftWithout = service.generateSmartTemplate(inputWithout, 0);
      // Verify behavior: returns null because 'تخفيض' alone does not match _offer
      expect(draftWithout, isNull);

      // With offer keyword:
      const inputWith = 'عرض تخفيض 100 %';
      final draftWith = service.generateSmartTemplate(inputWith, 0);
      expect(draftWith, isNotNull);
      expect(draftWith!.titleAr, contains('100%'));
      expect(draftWith.titleAr, isNot(matches(isolated00)));
    });

    test('Scenario 23: Mixed text with discount and food items', () {
      const input = 'عرض كشري خصم 100% اليوم';
      final draft = service.generateSmartTemplate(input, 1);
      expect(draft, isNotNull);
      expect(draft!.titleAr, contains('100%'));
      expect(draft.titleAr, contains('خصم 100%'));
      expect(draft.titleAr, isNot(contains('خصم 00%')));
      expect(draft.messageAr, contains('كشري'));
      expect(draft.messageEn, contains('koshari'));
      expect(draft.titleEn, contains('100%'));
    });

    test('Scenario 24: Non-breaking space and tab before percent symbol', () {
      const nonBreakingSpaceInput = 'عرض خصم 100\u00A0% بمناسبة السنة الجديدة';
      final draft = service.generateSmartTemplate(nonBreakingSpaceInput, 0);
      expect(draft, isNotNull);
      expect(draft!.titleAr, contains('100%'));

      const tabSpaceInput = 'عرض خصم 100\t% خاص';
      final draftTab = service.generateSmartTemplate(tabSpaceInput, 0);
      expect(draftTab, isNotNull);
      expect(draftTab!.titleAr, contains('100%'));
    });

    test('Scenario 25: All variants (0, 1, 2) never output "00%" or "00% off" for 100% input', () {
      const inputs = [
        'عرض خصم 100% اليوم',
        'عرض خصم 100 % اليوم',
        'عرض خصم ١٠٠٪ اليوم',
        'خصم 100% لفترة محدودة',
      ];

      final isolated00 = RegExp(r'(^|[^\d])00%');
      final isolatedArabic00 = RegExp(r'(^|[^٠-٩])٠٠%');
      final isolated00Off = RegExp(r'(^|[^\d])00% off');
      final isolated00Less = RegExp(r'(^|[^\d])00% less');

      for (final input in inputs) {
        for (int v = 0; v < 3; v++) {
          final draft = service.generateSmartTemplate(input, v);
          expect(draft, isNotNull, reason: 'Failed to generate draft for input: "$input", variant: $v');
          expect(draft!.titleAr, isNot(contains('خصم 00%')),
              reason: 'Variant $v output "خصم 00%" for input: "$input"');
          expect(draft.titleAr, isNot(contains('خصم ٠٠%')),
              reason: 'Variant $v output "خصم ٠٠%" for input: "$input"');
          expect(draft.titleAr, isNot(matches(isolated00)),
              reason: 'Variant $v contained isolated "00%" in titleAr for input: "$input"');
          expect(draft.titleAr, isNot(matches(isolatedArabic00)),
              reason: 'Variant $v contained isolated "٠٠%" in titleAr for input: "$input"');
          expect(draft.titleEn, isNot(matches(isolated00Off)),
              reason: 'Variant $v contained "00% off" in titleEn for input: "$input"');
          expect(draft.titleEn, isNot(matches(isolated00Less)),
              reason: 'Variant $v contained "00% less" in titleEn for input: "$input"');
        }
      }
    });

    test('Scenario 26: Emoji handling in 100% discount smart templates', () {
      // Admin requests emoji explicitly:
      const inputWithEmoji = 'عرض خصم 100% مع شوية إيموجي';
      final draftWithEmoji = service.generateSmartTemplate(inputWithEmoji, 0);
      expect(draftWithEmoji, isNotNull);
      expect(draftWithEmoji!.titleAr, contains('100%'));

      // Admin explicitly forbids emoji:
      const inputNoEmoji = 'عرض خصم 100% بدون إيموجي نهائي';
      final draftNoEmoji = service.generateSmartTemplate(inputNoEmoji, 0);
      expect(draftNoEmoji, isNotNull);
      expect(draftNoEmoji!.titleAr, contains('100%'));
      expect(service.stripEmoji(draftNoEmoji.titleAr), equals(draftNoEmoji.titleAr));
    });
  });
}
