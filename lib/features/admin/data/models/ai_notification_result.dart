class AiNotificationResult {
  static const _validTypes = <String>{'meal', 'reminder', 'update'};
  static const _validDestinations = <String>{
    'home',
    'meal',
    'vault',
    'explore',
    'settings',
    'custom',
  };
  static const _validAudiences = <String>{'all', 'new', 'returning'};

  final String type; // meal, reminder, update
  final String titleAr;
  final String titleEn;
  final String messageAr;
  final String messageEn;
  final String destination; // home, meal, vault, explore, settings, custom
  final String mealName;
  final String targetAudience; // all, new, returning

  const AiNotificationResult({
    required this.type,
    required this.titleAr,
    required this.titleEn,
    required this.messageAr,
    required this.messageEn,
    this.destination = 'home',
    this.mealName = '',
    this.targetAudience = 'all',
  });

  factory AiNotificationResult.fromJson(Map<String, dynamic> json) {
    final rawType = json['type']?.toString().trim().toLowerCase() ?? '';
    final type = _normalizeType(rawType);

    final rawDest = json['destination']?.toString().trim().toLowerCase() ?? '';
    final destination = _normalizeDestination(rawDest, type);

    final rawAudience =
        json['targetAudience']?.toString().trim().toLowerCase() ??
        json['audience']?.toString().trim().toLowerCase() ??
        '';
    final targetAudience = _normalizeAudience(rawAudience);

    final mealName = json['mealName']?.toString().trim() ??
        json['meal']?.toString().trim() ??
        '';

    return AiNotificationResult(
      type: type,
      titleAr: json['titleAr']?.toString() ?? '',
      titleEn: json['titleEn']?.toString() ?? '',
      messageAr: json['messageAr']?.toString() ?? '',
      messageEn: json['messageEn']?.toString() ?? '',
      destination: destination,
      mealName: mealName,
      targetAudience: targetAudience,
    );
  }

  static String _normalizeType(String val) {
    if (_validTypes.contains(val)) return val;
    if (val.contains('تذكير') || val.contains('remind')) return 'reminder';
    if (val.contains('تحديث') || val.contains('update') || val.contains('جديد')) {
      return 'update';
    }
    if (val.contains('وجب') ||
        val.contains('أكل') ||
        val.contains('اكل') ||
        val.contains('meal')) {
      return 'meal';
    }
    return 'meal';
  }

  static String _normalizeDestination(String val, String type) {
    if (_validDestinations.contains(val)) return val;
    if (val.isEmpty) return 'home';
    if (val.contains('خزان') || val.contains('خزن') || val.contains('vault')) {
      return 'vault';
    }
    if (val.contains('استكشاف') || val.contains('explore')) return 'explore';
    if (val.contains('إعداد') || val.contains('اعداد') || val.contains('setting')) {
      return 'settings';
    }
    if (val.contains('رابط') || val.contains('custom')) return 'custom';
    if (val.contains('رئيس') || val.contains('home')) return 'home';
    if (val.contains('وجب') ||
        val.contains('أكل') ||
        val.contains('اكل') ||
        val.contains('meal') ||
        val.contains('وصف')) {
      return 'meal';
    }
    return 'home';
  }

  static String _normalizeAudience(String val) {
    if (_validAudiences.contains(val)) return val;
    if (val.contains('جدد') || val.contains('جديد') || val.contains('new')) {
      return 'new';
    }
    if (val.contains('عائد') || val.contains('قديم') || val.contains('return')) {
      return 'returning';
    }
    return 'all';
  }

  /// Sent back to the model as `previousNotification` so a refinement idea
  /// ("خلّيها أقصر") edits this draft instead of starting from scratch.
  Map<String, dynamic> toJson() => {
    'type': type,
    'destination': destination,
    if (mealName.isNotEmpty) 'mealName': mealName,
    'targetAudience': targetAudience,
    'titleAr': titleAr,
    'titleEn': titleEn,
    'messageAr': messageAr,
    'messageEn': messageEn,
  };
}
