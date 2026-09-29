import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'models/ai_provider.dart';
import 'models/ai_notification_result.dart';

class AiServiceException implements Exception {
  final String message;
  const AiServiceException(this.message);
  @override
  String toString() => message;
}

final aiNotificationServiceProvider = Provider<AiNotificationService>((ref) {
  return AiNotificationService();
});

class AiNotificationService {
  static const String _geminiBaseUrl =
      'https://generativelanguage.googleapis.com/v1beta/models/';

  Future<AiNotificationResult> generateNotification({
    AiSelectedTarget? target,
    required List<AiProvider> allProviders,
    required String userPrompt,
  }) async {
    final List<AiProvider> providersToTry;

    if (target == null) {
      providersToTry = allProviders;
    } else {
      final wanted = target.provider.toLowerCase();
      final keys = allProviders
          .where((p) => p.provider.toLowerCase() == wanted)
          .toList();
      if (keys.isEmpty) {
        throw const AiServiceException('لا يوجد مفاتيح مفعّلة للمزود المحدد.');
      }
      providersToTry = [
        for (final key in keys) _withOverriddenModel(key, target.model),
      ];
    }

    if (providersToTry.isEmpty) {
      throw const AiServiceException('لا يوجد مزودين متاحين.');
    }

    List<String> errorLogs = [];
    for (final provider in providersToTry) {
      try {
        final responseBody = await _makeRequest(provider, userPrompt);
        return _parseResponse(responseBody, provider.provider);
      } catch (e) {
        errorLogs.add('${provider.name}: $e');
        continue;
      }
    }

    throw AiServiceException('فشلت جميع المحاولات:\n' + errorLogs.join('\n'));
  }

  /// The selected model wins over whatever the key document stored, so one
  /// provider group can serve every model it hosts.
  AiProvider _withOverriddenModel(AiProvider key, String model) {
    return AiProvider(
      id: key.id,
      name: key.name,
      provider: key.provider,
      model: model,
      apiKey: key.apiKey,
      endpoint: key.endpoint,
      isActive: key.isActive,
      isFree: key.isFree,
      rateLimit: key.rateLimit,
      notes: key.notes,
    );
  }

  Future<String> _makeRequest(AiProvider provider, String userPrompt) async {
    switch (provider.provider.toLowerCase()) {
      case 'gemini':
        return _buildGeminiRequest(provider, userPrompt);
      case 'groq':
      case 'openrouter':
        return _buildGroqRequest(provider, userPrompt);
      default:
        throw const AiServiceException('مزود الذكاء الاصطناعي غير مدعوم.');
    }
  }

  Future<String> _buildGeminiRequest(
    AiProvider provider,
    String userPrompt,
  ) async {
    final uri = Uri.parse(
      '$_geminiBaseUrl${provider.model}:generateContent'
      '?key=${provider.apiKey}',
    );
    final headers = <String, String>{'Content-Type': 'application/json'};
    // Google's newer free-tier keys authenticate by header, not by query key.
    if (provider.apiKey.startsWith('AQ.')) {
      headers['Authorization'] = 'Bearer ${provider.apiKey}';
    }
    final response = await http.post(
      uri,
      headers: headers,
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": _buildSystemPrompt()},
              {"text": userPrompt},
            ],
          },
        ],
        "generationConfig": {
          "responseMimeType": "application/json",
          "temperature": 0.85,
        },
      }),
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const AiServiceException(
        'مفتاح الـ API غير صالح أو منتهي. راجع إعدادات المزود في Firebase.',
      );
    }
    if (response.statusCode == 429) {
      throw const AiServiceException(
        'تم تجاوز حد الاستخدام المجاني. جرب موديل تاني أو استنى شوية.',
      );
    }
    if (response.statusCode != 200) {
      throw AiServiceException(
        'خطأ في الاتصال بالخادم (${response.statusCode})',
      );
    }
    return response.body;
  }

  Future<String> _buildGroqRequest(
    AiProvider provider,
    String userPrompt,
  ) async {
    final uri = Uri.parse(provider.endpoint);
    final response = await http.post(
      uri,
      headers: {
        'Content-Type': 'application/json',
        'Authorization': 'Bearer ${provider.apiKey}',
        // Cloudflare rejects the Dart default client with a 403.
        'User-Agent': 'Mozilla/5.0',
      },
      body: jsonEncode({
        "model": provider.model,
        "temperature": 0.85,
        "messages": [
          {"role": "system", "content": _buildSystemPrompt()},
          {"role": "user", "content": userPrompt},
        ],
        "response_format": {"type": "json_object"},
      }),
    );

    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const AiServiceException(
        'مفتاح الـ API غير صالح أو منتهي. راجع إعدادات المزود في Firebase.',
      );
    }
    if (response.statusCode == 429) {
      throw const AiServiceException(
        'تم تجاوز حد الاستخدام المجاني. جرب موديل تاني أو استنى شوية.',
      );
    }
    if (response.statusCode != 200) {
      throw AiServiceException(
        'خطأ في الاتصال بالخادم (${response.statusCode})',
      );
    }
    return response.body;
  }

  AiNotificationResult _parseResponse(
    String responseBody,
    String providerType,
  ) {
    try {
      final json = jsonDecode(responseBody);
      String textContent = '';
      final kind = providerType.toLowerCase();

      if (kind == 'gemini') {
        textContent =
            json['candidates'][0]['content']['parts'][0]['text'] as String;
      } else if (kind == 'groq' || kind == 'openrouter') {
        textContent = json['choices'][0]['message']['content'] as String;
      }

      final resultJson = jsonDecode(textContent) as Map<String, dynamic>;
      return AiNotificationResult.fromJson(resultJson);
    } catch (e) {
      throw const AiServiceException(
        'الموديل رد برد غير مفهوم. جرب تاني بصياغة مختلفة.',
      );
    }
  }

  String _buildSystemPrompt() {
    return '''
أنت مؤلف إعلانات محترف لتطبيق «أكلة النهاردة» — تطبيق مصري أصيل لإقتراح الأكل اليومي.

مهمتك: صياغة إشعارات (Notifications) جذابة ومبهجة للمستخدمين.

قواعد صارمة:
1. اللهجة المصرية الشعبية المحبوبة. بدون فصحى جافة. خلّي الكلام يفتّح النفس. نوع في أسلوبك كل مرة: استخدم أحياناً فكاهة، وأحياناً حماس، وأحياناً أسلوب دافئ. إياك وتكرار نفس الجمل والقوالب الثابتة لتفادي الملل.
2. ممنوع نهائياً وضع أي إيموجي في أي حقل من الحقول إلا إذا ذكر المشرف كلمة "إيموجي" أو "emoji" صراحة في طلبه.
3. العنوان لازم يكون قصير وخاطف (من 3 إلى 8 كلمات).
4. الرسالة أطول شوية وبتدي تفاصيل أو بتكمل المعنى بأسلوب مصري لطيف ومتجدد.
5. الترجمة الإنجليزية لازم تنقل نفس الروح والمرح، مش ترجمة حرفية مملة.
6. حقل type يكون "meal" لو الموضوع عن أكلة، أو "reminder" لو تذكير، أو "update" لو تحديث في التطبيق.

أجب **فقط** بكائن JSON واحد بهذا الشكل بالضبط بدون أي نص إضافي:
{
  "type": "meal",
  "titleAr": "...",
  "titleEn": "...",
  "messageAr": "...",
  "messageEn": "..."
}
''';
  }
}
