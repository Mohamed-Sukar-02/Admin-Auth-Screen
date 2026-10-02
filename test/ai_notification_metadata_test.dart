import 'package:daily_meal/features/admin/data/ai_notification_service.dart';
import 'package:daily_meal/features/admin/data/models/ai_notification_result.dart';
import 'package:daily_meal/features/admin/data/models/cloud_meal.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('AI Notification Metadata & Normalization', () {
    test('serializes and deserializes destination, mealName, and targetAudience', () {
      const result = AiNotificationResult(
        titleAr: 'كشري سخن',
        messageAr: 'أحلى كشري على الغدا',
        titleEn: 'Hot Koshari',
        messageEn: 'Best koshari for lunch',
        type: 'meal',
        destination: 'meal',
        mealName: 'كشري',
        targetAudience: 'returning',
      );

      final map = result.toJson();
      expect(map['destination'], 'meal');
      expect(map['mealName'], 'كشري');
      expect(map['targetAudience'], 'returning');

      final fromMap = AiNotificationResult.fromJson(map);
      expect(fromMap.destination, 'meal');
      expect(fromMap.mealName, 'كشري');
      expect(fromMap.targetAudience, 'returning');
      expect(fromMap.type, 'meal');
    });

    test('normalizes Arabic destination and audience strings gracefully', () {
      final jsonWithArabic = {
        'titleAr': 'ملوخية بالشهقة',
        'messageAr': 'ملوخية سخنة تفتح النفس',
        'titleEn': 'Molokhia',
        'messageEn': 'Hot and fresh',
        'type': 'وجبة',
        'destination': 'خزانة الأكلات',
        'targetAudience': 'المستخدمون الجدد',
      };

      final result = AiNotificationResult.fromJson(jsonWithArabic);
      expect(result.type, 'meal');
      expect(result.destination, 'vault');
      expect(result.targetAudience, 'new');
    });

    test('defaults missing metadata fields safely for backward compatibility', () {
      final legacyJson = {
        'titleAr': 'تذكير',
        'messageAr': 'معاد الغدا',
        'titleEn': 'Reminder',
        'messageEn': 'Lunch time',
      };

      final result = AiNotificationResult.fromJson(legacyJson);
      expect(result.type, 'meal');
      expect(result.destination, 'home');
      expect(result.mealName, isEmpty);
      expect(result.targetAudience, 'all');
    });

    test('generateSmartTemplate with targetMeal produces specific meal notification', () {
      final service = AiNotificationService();
      final meal = CloudMeal(
        id: 'meal_123',
        name: 'كفتة مشوية',
        proteinType: 'beef',
        carbsType: 'bread',
        category: 'dry_sandwich',
        prepTimeMinutes: 40,
        createdAt: DateTime.now(),
      );

      final template = service.generateSmartTemplate(
        'عايز إشعار للكفتة',
        0,
        targetMeal: meal,
      );

      expect(template, isNotNull);
      expect(template!.destination, 'meal');
      expect(template.mealName, 'كفتة مشوية');
      expect(template.titleAr, contains('كفتة مشوية'));
      expect(template.messageAr, contains('كفتة مشوية'));
    });
  });
}
