class AiProvider {
  final String id;
  final String name;
  final String provider; // openai, gemini, anthropic, groq, ollama, custom
  final String model;
  final String apiKey;
  final String endpoint;
  final bool isActive;
  final bool isFree;
  final String rateLimit;
  final String? notes;

  const AiProvider({
    required this.id,
    required this.name,
    required this.provider,
    required this.model,
    required this.apiKey,
    required this.endpoint,
    this.isActive = true,
    this.isFree = true,
    this.rateLimit = '',
    this.notes,
  });

  factory AiProvider.fromMap(Map<String, dynamic> map, String docId) {
    return AiProvider(
      id: docId,
      name: map['name'] as String? ?? '',
      provider: map['provider'] as String? ?? '',
      model: map['model'] as String? ?? '',
      apiKey: map['apiKey'] as String? ?? '',
      endpoint: map['endpoint'] as String? ?? '',
      isActive: map['isActive'] as bool? ?? true,
      isFree: map['isFree'] as bool? ?? true,
      rateLimit: map['rateLimit'] as String? ?? '',
      notes: map['notes'] as String?,
    );
  }
}

/// A provider+model pair chosen by the admin, independent of which key document
/// supplies the credentials at request time.
class AiSelectedTarget {
  final String provider; // 'gemini', 'groq', 'openrouter'
  final String model; // e.g. 'qwen/qwen3-32b', 'gemini-2.5-flash'
  final String displayName;

  const AiSelectedTarget({
    required this.provider,
    required this.model,
    required this.displayName,
  });

  @override
  bool operator ==(Object other) =>
      identical(this, other) ||
      other is AiSelectedTarget &&
          runtimeType == other.runtimeType &&
          provider == other.provider &&
          model == other.model;

  @override
  int get hashCode => provider.hashCode ^ model.hashCode;
}
