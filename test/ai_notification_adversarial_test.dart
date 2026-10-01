import 'dart:convert';
import 'package:daily_meal/features/admin/data/ai_notification_service.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late AiNotificationService service;

  setUp(() {
    service = AiNotificationService();
  });

  group('Adversarial Challenge: Groq Format Compatibility', () {
    test('standard Groq response format with "notifications" array', () {
      const groqJson = '''
      {
        "notifications": [
          {"label": "L1", "prompt": "P1"}
        ]
      }
      ''';
      final result = AiNotificationService.parseDynamicSuggestions(groqJson);
      expect(result, hasLength(1));
      expect(result.first['label'], equals('L1'));
      expect(result.first['prompt'], equals('P1'));
    });

    test('Groq response with multiple notifications and extra metadata fields', () {
      const groqMultiJson = '''
      {
        "id": "chatcmpl-12345",
        "object": "chat.completion",
        "created": 1700000000,
        "model": "llama-3.3-70b-versatile",
        "notifications": [
          {"label": "وجبة اليوم", "prompt": "اقتراح كفتة مشوية", "confidence": 0.98},
          {"label": "عرض خاص", "prompt": "خصم 20% على الطواجن", "tags": ["hot", "deal"]},
          {"label": "فطار الصبح", "prompt": "فول وطعمية سخنة", "category": "breakfast"}
        ]
      }
      ''';
      final result = AiNotificationService.parseDynamicSuggestions(groqMultiJson);
      expect(result, hasLength(3));
      expect(result[0]['label'], equals('وجبة اليوم'));
      expect(result[1]['prompt'], contains('20%'));
      expect(result[2]['label'], equals('فطار الصبح'));
    });

    test('Groq response with empty notifications array returns empty list safely', () {
      const groqEmptyJson = '{"notifications": []}';
      final result = AiNotificationService.parseDynamicSuggestions(groqEmptyJson);
      expect(result, isEmpty);
    });

    test('Groq response where notifications contains partially missing keys', () {
      const groqPartialJson = '''
      {
        "notifications": [
          {"label": "فقط عنوان"},
          {"prompt": "فقط برومبت"},
          {"label": "", "prompt": ""}
        ]
      }
      ''';
      final result = AiNotificationService.parseDynamicSuggestions(groqPartialJson);
      expect(result, hasLength(2));
      expect(result[0]['label'], equals('فقط عنوان'));
      expect(result[0]['prompt'], equals(''));
      expect(result[1]['label'], equals(''));
      expect(result[1]['prompt'], equals('فقط برومبت'));
    });
  });

  group('Adversarial Challenge: Gemini Schema Format Compatibility', () {
    test('Gemini schema format with nested fields inside notifications items', () {
      const geminiNestedJson = '''
      {
        "notifications": [
          {
            "label": "طبق اليوم",
            "prompt": "ملوخية سخنة بالتقلية",
            "details": {
              "difficulty": "easy",
              "prep_time_minutes": 30,
              "ingredients": ["شوربة", "ملوخية", "توم", "كزبرة"]
            }
          },
          {
            "label": "حلويات",
            "prompt": "بسبوسة بالمكسرات",
            "meta": {"servings": 4}
          }
        ]
      }
      ''';
      final result = AiNotificationService.parseDynamicSuggestions(geminiNestedJson);
      expect(result, hasLength(2));
      expect(result[0]['label'], equals('طبق اليوم'));
      expect(result[0]['prompt'], equals('ملوخية سخنة بالتقلية'));
      expect(result[1]['label'], equals('حلويات'));
    });

    test('Gemini format with non-string primitive types inside label and prompt', () {
      const nonStringValuesJson = '''
      {
        "notifications": [
          {"label": 12345, "prompt": 67890},
          {"label": true, "prompt": false},
          {"label": ["أكلة", "سريعة"], "prompt": {"inner": "وصف"}}
        ]
      }
      ''';
      final result = AiNotificationService.parseDynamicSuggestions(nonStringValuesJson);
      expect(result, hasLength(3));
      expect(result[0]['label'], equals('12345'));
      expect(result[0]['prompt'], equals('67890'));
      expect(result[1]['label'], equals('true'));
      expect(result[1]['prompt'], equals('false'));
      expect(result[2]['label'], contains('أكلة'));
      expect(result[2]['prompt'], contains('وصف'));
    });

    test('Gemini raw candidates envelope passed directly to parser does not crash', () {
      const rawCandidatesJson = '''
      {
        "candidates": [
          {
            "content": {
              "parts": [
                {
                  "text": "{\\"notifications\\": [{\\"label\\": \\"L1\\", \\"prompt\\": \\"P1\\"}]}"
                }
              ]
            }
          }
        ]
      }
      ''';
      // Parser should not throw exception even when receiving the outer envelope
      final result = AiNotificationService.parseDynamicSuggestions(rawCandidatesJson);
      expect(result, isA<List<Map<String, String>>>());
    });
  });

  group('Adversarial Challenge: OpenRouter Format Compatibility', () {
    test('OpenRouter format with "suggestions" container key', () {
      const openRouterJson = '''
      {
        "suggestions": [
          {"label": "L2", "prompt": "P2"}
        ]
      }
      ''';
      final result = AiNotificationService.parseDynamicSuggestions(openRouterJson);
      expect(result, hasLength(1));
      expect(result.first['label'], equals('L2'));
      expect(result.first['prompt'], equals('P2'));
    });

    test('OpenRouter alternative format with "ideas" container key', () {
      const openRouterIdeasJson = '''
      {
        "ideas": [
          {"label": "كشري إكسبريس", "prompt": "أسرع طبق كشري في 15 دقيقة"}
        ]
      }
      ''';
      final result = AiNotificationService.parseDynamicSuggestions(openRouterIdeasJson);
      expect(result, hasLength(1));
      expect(result.first['label'], equals('كشري إكسبريس'));
      expect(result.first['prompt'], contains('كشري'));
    });

    test('OpenRouter arbitrary wrapper key containing a list fallback', () {
      const arbitraryWrapperJson = '''
      {
        "generated_items": [
          {"label": "سلطة بلدي", "prompt": "سلطة بلدي متبلة بالليمون والكمون"}
        ]
      }
      ''';
      final result = AiNotificationService.parseDynamicSuggestions(arbitraryWrapperJson);
      expect(result, hasLength(1));
      expect(result.first['label'], equals('سلطة بلدي'));
      expect(result.first['prompt'], contains('سلطة بلدي'));
    });
  });

  group('Adversarial Challenge: Fallback Legacy Format Compatibility', () {
    test('Fallback legacy bare JSON array format', () {
      const legacyArrayJson = '''
      [
        {"label": "L3", "prompt": "P3"},
        {"label": "شوربة عدس", "prompt": "شوربة تدفي في برد الشتاء"}
      ]
      ''';
      final result = AiNotificationService.parseDynamicSuggestions(legacyArrayJson);
      expect(result, hasLength(2));
      expect(result[0]['label'], equals('L3'));
      expect(result[0]['prompt'], equals('P3'));
      expect(result[1]['label'], equals('شوربة عدس'));
    });

    test('Legacy array with mixed corrupt types (primitives, nulls, empty maps)', () {
      const dirtyArrayJson = '''
      [
        {"label": "L3", "prompt": "P3"},
        null,
        12345,
        "corrupted item string",
        true,
        false,
        {},
        {"label": "   ", "prompt": "   "},
        {"label": "صالح", "prompt": "برومبت صالح"}
      ]
      ''';
      final result = AiNotificationService.parseDynamicSuggestions(dirtyArrayJson);
      expect(result, hasLength(2));
      expect(result[0]['label'], equals('L3'));
      expect(result[0]['prompt'], equals('P3'));
      expect(result[1]['label'], equals('صالح'));
      expect(result[1]['prompt'], equals('برومبت صالح'));
    });

    test('Empty legacy array returns empty list gracefully', () {
      expect(AiNotificationService.parseDynamicSuggestions('[]'), isEmpty);
      expect(AiNotificationService.parseDynamicSuggestions('[   ]'), isEmpty);
    });
  });

  group('Adversarial Challenge: Corrupted Non-JSON & Scalar JSON', () {
    test('Scalar JSON values do not throw unhandled exceptions', () {
      expect(AiNotificationService.parseDynamicSuggestions('"hello"'), isEmpty);
      expect(AiNotificationService.parseDynamicSuggestions('123'), isEmpty);
      expect(AiNotificationService.parseDynamicSuggestions('true'), isEmpty);
      expect(AiNotificationService.parseDynamicSuggestions('false'), isEmpty);
      expect(AiNotificationService.parseDynamicSuggestions('null'), isEmpty);
      expect(AiNotificationService.parseDynamicSuggestions('3.1415926535'), isEmpty);
    });

    test('Malformed and corrupt non-JSON strings return empty list without crash', () {
      final corruptInputs = [
        'Plain text without any json markers',
        '{"notifications": ', // truncated
        '{"notifications": [{"label": "unclosed',
        '<<< XML / HTML >>> <html><body>502 Bad Gateway</body></html>',
        'undefined',
        'NaN',
        '{key: value_without_quotes}',
        '{"notifications": "this is a string not an array"}',
        '{"notifications": 99999}',
        '{"notifications": true}',
        '{"notifications": null}',
        '{"notifications": {"inner": "not a list"}}',
        '```json\n{"notifications": [unparseable]\n```',
        '```json\n\n```',
        '   \n\t\r   ',
        '',
      ];

      for (final input in corruptInputs) {
        expect(
          () => AiNotificationService.parseDynamicSuggestions(input),
          returnsNormally,
          reason: 'Input should not throw: "$input"',
        );
        final res = AiNotificationService.parseDynamicSuggestions(input);
        expect(res, isEmpty, reason: 'Corrupt input should yield empty list: "$input"');
      }
    });

    test('Markdown fences variations (surrounding text, spacing)', () {
      const fencedWithTrailing = '''
      ```json
      {
        "notifications": [
          {"label": "L_Fence", "prompt": "P_Fence"}
        ]
      }
      ```
      ''';
      final result = AiNotificationService.parseDynamicSuggestions(fencedWithTrailing);
      expect(result, hasLength(1));
      expect(result.first['label'], equals('L_Fence'));
      expect(result.first['prompt'], equals('P_Fence'));
    });
  });

  group('Adversarial Challenge: R3 Discount Regex & 100% Boundary Tests', () {
    test('100% discount with varying spaces and representations', () {
      final inputs = [
        'خصم 100% لفترة محدودة',
        'خصم 100 % لفترة محدودة',
        'خصم  100   %  لفترة محدودة',
        'خصم 100٪ لفترة محدودة',
        'خصم ١٠٠٪ لفترة محدودة',
        'خصم  ١٠٠  ٪ لفترة محدودة',
      ];

      for (final input in inputs) {
        final draft = service.generateSmartTemplate(input, 0);
        expect(draft, isNotNull, reason: 'Failed to generate template for: $input');
        expect(draft!.titleAr, isNot(contains('خصم 00%')), reason: 'Truncation to 00% detected for: $input');
        expect(draft.titleAr, isNot(contains('خصم ٠٠%')), reason: 'Truncation to ٠٠% detected for: $input');
        expect(
          draft.titleAr.contains('100%') || draft.titleAr.contains('١٠٠%'),
          isTrue,
          reason: 'Title should contain full 100% or ١٠٠%: $input, got "${draft.titleAr}"',
        );
      }
    });

    test('Boundary 1-digit, 2-digit, and 3-digit discounts (1% to 100%)', () {
      final testCases = <String, String>{
        'خصم 1% فقط': '1%',
        'خصم 9% فقط': '9%',
        'خصم 10% كبير': '10%',
        'خصم 50% نصف السعر': '50%',
        'خصم 99% شبه مجاني': '99%',
        'خصم 100% مجاني بالكامل': '100%',
        'خصم ١% فقط': '١%',
        'خصم ٥٠% نص السعر': '٥٠%',
        'خصم ١٠٠% بالكامل': '١٠٠%',
      };

      testCases.forEach((prompt, expected) {
        final draft = service.generateSmartTemplate(prompt, 0);
        expect(draft, isNotNull);
        expect(draft!.titleAr, contains(expected));
      });
    });
  });

  group('Adversarial Challenge: Fuzzing & Crash Immunity Test', () {
    test('immunity against 100 randomly structured pseudo-fuzz inputs', () {
      final fuzzInputs = <String>[
        '{}',
        '{"a": []}',
        '{"a": null}',
        '{"notifications": [null, null, null]}',
        '{"notifications": [{"label": null, "prompt": null}]}',
        '{"notifications": [{"label": "   ", "prompt": ""}]}',
        '{"notifications": [{"label": "\\u0000\\u0001", "prompt": "\\n\\r"}]}',
        '{"notifications": [{"label": "${"A" * 1000}", "prompt": "${"B" * 2000}"}]}',
        '[{"a": 1}, {"b": 2}, {"label": "valid", "prompt": "valid"}]',
        '{"nested": {"nested2": {"notifications": [{"label": "L", "prompt": "P"}]}}}',
        '{"choices": [{"message": {"content": "not json"}}]}',
        '{"candidates": []}',
      ];

      // Add dynamic permutations
      for (int i = 0; i < 50; i++) {
        fuzzInputs.add(jsonEncode({
          'key_$i': i.isEven ? [i, 'str', null] : {'nested': i},
          'notifications': i % 3 == 0
              ? [{'label': 'L_$i', 'prompt': 'P_$i'}]
              : (i % 3 == 1 ? 'not_a_list' : []),
        }));
      }

      for (final input in fuzzInputs) {
        expect(
          () => AiNotificationService.parseDynamicSuggestions(input),
          returnsNormally,
          reason: 'Parser threw on fuzz input: $input',
        );
        final result = AiNotificationService.parseDynamicSuggestions(input);
        expect(result, isA<List<Map<String, String>>>());
        // Verify every returned item has valid string keys
        for (final item in result) {
          expect(item.containsKey('label'), isTrue);
          expect(item.containsKey('prompt'), isTrue);
          expect(item['label']!.isNotEmpty || item['prompt']!.isNotEmpty, isTrue);
        }
      }
    });
  });
}
