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
  Future<AiNotificationResult> generateNotification({
    required AiProvider provider,
    required String userPrompt,
  }) async {
    try {
      final responseBody = await _makeRequest(provider, userPrompt);
      return _parseResponse(responseBody, provider.provider);
    } catch (e) {
      if (e is AiServiceException) rethrow;
      throw AiServiceException('حصل خطأ غير متوقع: $e');
    }
  }

  Future<String> _makeRequest(AiProvider provider, String userPrompt) async {
    if (provider.provider == 'gemini') {
      return _buildGeminiRequest(provider, userPrompt);
    } else if (provider.provider == 'groq') {
      return _buildGroqRequest(provider, userPrompt);
    }
    throw const AiServiceException('مزود الذكاء الاصطناعي غير مدعوم.');
  }

  Future<String> _buildGeminiRequest(
    AiProvider provider,
    String userPrompt,
  ) async {
    final uri = Uri.parse('${provider.endpoint}?key=${provider.apiKey}');
    final response = await http.post(
      uri,
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        "contents": [
          {
            "parts": [
              {"text": _buildSystemPrompt()},
              {"text": userPrompt},
            ],
          },
        ],
        "generationConfig": {"responseMimeType": "application/json"},
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
      },
      body: jsonEncode({
        "model": provider.model,
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

      if (providerType == 'gemini') {
        textContent =
            json['candidates'][0]['content']['parts'][0]['text'] as String;
      } else if (providerType == 'groq') {
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
1. اللهجة المصرية الشعبية المحبوبة. بدون فصحى جافة. خلّي الكلام يفتّح النفس.
2. ممنوع نهائياً وضع أي إيموجي في أي حقل من الحقول إلا إذا ذكر المشرف كلمة "إيموجي" أو "emoji" صراحة في طلبه.
3. العنوان لازم يكون قصير وخاطف (من 3 إلى 8 كلمات).
4. الرسالة أطول شوية وبتدي تفاصيل أو بتكمل المعنى بأسلوب مصري لطيف.
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
