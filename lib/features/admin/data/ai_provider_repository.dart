import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'models/ai_provider.dart';

final aiProviderRepositoryProvider = Provider<AiProviderRepository>((ref) {
  return AiProviderRepository(firestore: FirebaseFirestore.instance);
});

final activeAiProvidersStreamProvider =
    StreamProvider.autoDispose<List<AiProvider>>((ref) {
      return ref.watch(aiProviderRepositoryProvider).streamActiveProviders();
    });

class AiProviderRepository {
  final FirebaseFirestore _firestore;

  AiProviderRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  CollectionReference<Map<String, dynamic>> get _providers =>
      _firestore.collection('ai_providers');

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
}
