class AiNotificationResult {
  static const _validTypes = <String>{'meal', 'reminder', 'update'};

  final String type; // meal, reminder, update
  final String titleAr;
  final String titleEn;
  final String messageAr;
  final String messageEn;

  const AiNotificationResult({
    required this.type,
    required this.titleAr,
    required this.titleEn,
    required this.messageAr,
    required this.messageEn,
  });

  factory AiNotificationResult.fromJson(Map<String, dynamic> json) {
    final type = json['type']?.toString().trim().toLowerCase() ?? '';
    return AiNotificationResult(
      type: _validTypes.contains(type) ? type : 'meal',
      titleAr: json['titleAr']?.toString() ?? '',
      titleEn: json['titleEn']?.toString() ?? '',
      messageAr: json['messageAr']?.toString() ?? '',
      messageEn: json['messageEn']?.toString() ?? '',
    );
  }

  /// Sent back to the model as `previousNotification` so a refinement idea
  /// ("خلّيها أقصر") edits this draft instead of starting from scratch.
  Map<String, dynamic> toJson() => {
    'type': type,
    'titleAr': titleAr,
    'titleEn': titleEn,
    'messageAr': messageAr,
    'messageEn': messageEn,
  };
}
