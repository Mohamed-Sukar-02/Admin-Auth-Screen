import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

final appFeaturesRepositoryProvider = Provider<AppFeaturesRepository>((ref) {
  return AppFeaturesRepository(firestore: FirebaseFirestore.instance);
});

/// The knowledge base the notification generator retrieves from: the ten most
/// recently released features.
final activeAppFeaturesProvider = FutureProvider.autoDispose<List<AppFeature>>((ref) {
  return ref.watch(appFeaturesRepositoryProvider).getActiveFeatures();
});

class AppFeature {
  final String id;
  final String title;
  final String description;
  final List<String> targetAudience;
  final DateTime releaseDate;
  final bool isActive;

  const AppFeature({
    required this.id,
    required this.title,
    required this.description,
    required this.targetAudience,
    required this.releaseDate,
    this.isActive = true,
  });

  factory AppFeature.fromMap(Map<String, dynamic> map, String docId) {
    return AppFeature(
      id: docId,
      title: map['title'] as String? ?? '',
      description: map['description'] as String? ?? '',
      targetAudience: _readAudience(map['targetAudience']),
      releaseDate: _readReleaseDate(map['releaseDate']),
      isActive: map['isActive'] as bool? ?? true,
    );
  }
}

class AppFeaturesRepository {
  static const int _knowledgeBaseSize = 10;

  final FirebaseFirestore _firestore;

  AppFeaturesRepository({required FirebaseFirestore firestore})
    : _firestore = firestore;

  CollectionReference<Map<String, dynamic>> get _features =>
      _firestore.collection('app_features');

  Future<List<AppFeature>> getActiveFeatures() async {
    final snapshot = await _features
        .where('isActive', isEqualTo: true)
        .orderBy('releaseDate', descending: true)
        .limit(_knowledgeBaseSize)
        .get();

    return snapshot.docs
        .map((doc) => AppFeature.fromMap(doc.data(), doc.id))
        .toList();
  }
}

// Deliberately far in the past: an undated feature must not read as a new one
// when the generator turns release dates into prompts.
final DateTime _unknownRelease = DateTime(1970);

List<String> _readAudience(Object? value) {
  if (value is! List) return const [];
  return value
      .map((entry) => entry.toString().trim())
      .where((entry) => entry.isNotEmpty)
      .toList();
}

// Firestore hands back a Timestamp, but hand-authored and imported documents
// have also stored the date as an ISO string or a millisecond count.
DateTime _readReleaseDate(Object? value) {
  if (value is Timestamp) return value.toDate();
  if (value is String) return DateTime.tryParse(value) ?? _unknownRelease;
  if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
  return _unknownRelease;
}
