import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/ai_provider.dart';

const Map<String, List<String>> defaultAiModels = {
  'gemini': [
    'gemini-3.8-flash',
    'gemini-3.7-flash',
    'gemini-3.6-flash',
    'gemini-3.5-flash',
  ],
  'groq': [
    'qwen/qwen3.8-27b',
    'openai/gpt-oss-120b',
    'openai/gpt-oss-20b',
  ],
  'openrouter': [
    'openrouter/free',
    'qwen/qwen3.8-27b:free',
    'meta-llama/llama-3.3-70b-instruct',
  ],
};

final aiProviderRepositoryProvider = Provider<AiProviderRepository>((ref) {
  return AiProviderRepository(firestore: FirebaseFirestore.instance);
});

final activeAiProvidersStreamProvider =
    StreamProvider.autoDispose<List<AiProvider>>((ref) {
      return ref.watch(aiProviderRepositoryProvider).streamActiveProviders();
    });

final customAiModelsStreamProvider =
    StreamProvider.autoDispose<Map<String, List<String>>>((ref) {
      return ref.watch(aiProviderRepositoryProvider).streamCustomModels();
    });

class AiProviderRepository {
  final FirebaseFirestore _firestore;

  AiProviderRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  CollectionReference<Map<String, dynamic>> get _providers =>
      _firestore.collection('ai_providers');

  DocumentReference<Map<String, dynamic>> get _aiModelsDoc =>
      _firestore.collection('admin_config').doc('ai_models');

  Stream<List<AiProvider>> streamActiveProviders() {
    return _providers
        .where('isActive', isEqualTo: true)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => AiProvider.fromMap(doc.data(), doc.id))
              .toList(),
        );
  }

  Stream<Map<String, List<String>>> streamCustomModels() {
    return _aiModelsDoc.snapshots().map((doc) {
      if (!doc.exists || doc.data() == null) {
        return defaultAiModels;
      }
      final data = doc.data()!;
      final map = <String, List<String>>{};
      for (final provider in defaultAiModels.keys) {
        if (data[provider] is List && (data[provider] as List).isNotEmpty) {
          map[provider] = List<String>.from(data[provider] as List);
        } else {
          map[provider] = List<String>.from(defaultAiModels[provider]!);
        }
      }
      for (final key in data.keys) {
        if (!map.containsKey(key) && data[key] is List) {
          map[key] = List<String>.from(data[key] as List);
        }
      }
      return map;
    }).handleError((_) => defaultAiModels);
  }

  Future<void> updateCustomModels(String provider, List<String> models) async {
    await _aiModelsDoc.set({provider: models}, SetOptions(merge: true));
  }
}
