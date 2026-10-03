import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../domain/duplicate_candidate.dart';
import '../domain/similarity_engine.dart';
import 'models/cloud_meal.dart';
import 'models/ignored_duplicate.dart';

final vaultAdminRepositoryProvider = Provider<VaultAdminRepository>((ref) {
  return VaultAdminRepository(firestore: FirebaseFirestore.instance);
});

final ignoredPairKeysStreamProvider =
    StreamProvider.autoDispose<Set<String>>((ref) {
  final repo = ref.watch(vaultAdminRepositoryProvider);
  return repo.streamIgnoredPairKeys();
});

final vaultMealsStreamProvider = StreamProvider.autoDispose<List<CloudMeal>>((
  ref,
) {
  final repo = ref.watch(vaultAdminRepositoryProvider);
  return repo.streamVaultMeals();
});

final stagingMealsStreamProvider = StreamProvider.autoDispose<List<CloudMeal>>((
  ref,
) {
  final repo = ref.watch(vaultAdminRepositoryProvider);
  return repo.streamStagingMeals();
});

final adminNotificationsStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final repo = ref.watch(vaultAdminRepositoryProvider);
      return repo.getNotifications();
    });

final adminDraftsStreamProvider =
    StreamProvider.autoDispose<List<Map<String, dynamic>>>((ref) {
      final repo = ref.watch(vaultAdminRepositoryProvider);
      return repo.getDrafts();
    });

class VaultAdminRepository {
  final FirebaseFirestore _firestore;

  VaultAdminRepository({FirebaseFirestore? firestore})
    : _firestore = firestore ?? FirebaseFirestore.instance;

  CollectionReference<Map<String, dynamic>> get _vaultRef =>
      _firestore.collection('vault_meals');

  CollectionReference<Map<String, dynamic>> get _stagingRef =>
      _firestore.collection('staging_meals');

  CollectionReference<Map<String, dynamic>> get _backupRef =>
      _firestore.collection('backup_meals');

  CollectionReference<Map<String, dynamic>> get _ignoredDuplicatesRef =>
      _firestore.collection('ignored_duplicates');

  /// A backup is one meta document naming fixed-size snapshot chunks. Every
  /// request then touches a single document, which is what the role-based
  /// rules can afford: listing `backup_meals` would re-read the caller's admin
  /// document for every row and blow Firestore's access budget.
  static const String _backupMetaId = '_snapshot_meta';
  static const int _backupChunkSize = 400;

  /// Writes per commit. Each write costs the rules one document read (the
  /// caller's role) and Firestore allows 20 per multi-document request.
  static const int _writesPerCommit = 8;

  /// Creates a complete copy of `vault_meals` into `backup_meals`.
  /// Deletes the previous snapshot first.
  Future<void> backupVault() async {
    // 1. Read the vault — `vault_meals` is publicly readable, so this costs
    //    the rules nothing no matter how many meals there are.
    final vaultMeals = await _vaultRef.get();
    final entries = <String, Map<String, dynamic>>{
      for (final doc in vaultMeals.docs) doc.id: doc.data(),
    };

    // 2. Drop the previous snapshot by the ids its meta recorded.
    await _deletePreviousBackup();

    // 3. Write the new chunks, then the meta that names them.
    final ids = entries.keys.toList()..sort();
    final chunkIds = <String>[];
    for (var i = 0; i < ids.length; i += _backupChunkSize) {
      final chunk = <String, Map<String, dynamic>>{};
      for (final id in ids.skip(i).take(_backupChunkSize)) {
        chunk[id] = entries[id]!;
      }
      final chunkId = '_snapshot_${chunkIds.length}';
      await _backupRef.doc(chunkId).set({
        'meals': chunk,
        'count': chunk.length,
      });
      chunkIds.add(chunkId);
    }

    await _backupRef.doc(_backupMetaId).set({
      'createdAt': FieldValue.serverTimestamp(),
      'chunkIds': chunkIds,
      'count': entries.length,
    });
  }

  /// Restores `backup_meals` into `vault_meals`.
  /// Deletes the current `vault_meals` first!
  Future<void> restoreVault() async {
    final restored = await _readBackup();
    if (restored.isEmpty) {
      throw Exception('لا يوجد نسخة احتياطية جاهزة؛ ارفع نسخة احتياطية أولاً');
    }

    final current = await _vaultRef.get();
    await _deleteInChunks(_vaultRef, [for (final doc in current.docs) doc.id]);
    await _writeInChunks(_vaultRef, restored);
  }

  Future<void> _deletePreviousBackup() async {
    final meta = await _backupRef.doc(_backupMetaId).get();
    final chunkIds = _chunkIdsOf(meta.data());
    await _backupRef.doc(_backupMetaId).delete();
    await _deleteInChunks(_backupRef, chunkIds);
  }

  Future<Map<String, Map<String, dynamic>>> _readBackup() async {
    final meta = await _backupRef.doc(_backupMetaId).get();
    final meals = <String, Map<String, dynamic>>{};

    for (final chunkId in _chunkIdsOf(meta.data())) {
      final chunk = await _backupRef.doc(chunkId).get();
      final data = chunk.data()?['meals'];
      if (data is! Map) continue;
      data.forEach((key, value) {
        if (key is String && value is Map) {
          meals[key] = Map<String, dynamic>.from(value);
        }
      });
    }

    return meals;
  }

  static List<String> _chunkIdsOf(Map<String, dynamic>? meta) {
    final ids = meta?['chunkIds'];
    return ids is List ? ids.whereType<String>().toList() : const <String>[];
  }

  Future<void> _deleteInChunks(
    CollectionReference<Map<String, dynamic>> collection,
    List<String> ids,
  ) async {
    for (var i = 0; i < ids.length; i += _writesPerCommit) {
      final batch = _firestore.batch();
      for (final id in ids.skip(i).take(_writesPerCommit)) {
        batch.delete(collection.doc(id));
      }
      await batch.commit();
    }
  }

  Future<void> _writeInChunks(
    CollectionReference<Map<String, dynamic>> collection,
    Map<String, Map<String, dynamic>> docs,
  ) async {
    final ids = docs.keys.toList();
    for (var i = 0; i < ids.length; i += _writesPerCommit) {
      final batch = _firestore.batch();
      for (final id in ids.skip(i).take(_writesPerCommit)) {
        batch.set(collection.doc(id), docs[id]!);
      }
      await batch.commit();
    }
  }

  /// Stream all approved meals from `vault_meals`
  Stream<List<CloudMeal>> streamVaultMeals() {
    return _vaultRef.orderBy('createdAt', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs
          .map((doc) => CloudMeal.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Stream all user-suggested meals waiting in `staging_meals`
  Stream<List<CloudMeal>> streamStagingMeals() {
    return _stagingRef.orderBy('createdAt', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs
          .map((doc) => CloudMeal.fromMap(doc.data(), doc.id))
          .toList();
    });
  }

  /// Add a new meal directly to `vault_meals`
  Future<void> addVaultMeal(CloudMeal meal) async {
    final docRef = _vaultRef.doc();
    final newMeal = meal.copyWith(id: docRef.id, status: 'approved');
    await docRef.set(newMeal.toMap());
  }

  /// Update an existing meal in `vault_meals`
  Future<void> updateVaultMeal(CloudMeal meal) async {
    final updated = meal.copyWith(updatedAt: DateTime.now());
    await _vaultRef.doc(meal.id).update(updated.toMap());
  }

  /// Toggle whether a meal is a starter pack meal for new users
  Future<void> toggleStarterMeal(CloudMeal meal) async {
    final updated = meal.copyWith(
      isStarterMeal: !meal.isStarterMeal,
      updatedAt: DateTime.now(),
    );
    await _vaultRef.doc(meal.id).update({
      'isStarterMeal': updated.isStarterMeal,
      'updatedAt': updated.updatedAt!.toIso8601String(),
    });
  }

  /// Delete a meal from `vault_meals`
  Future<void> deleteVaultMeal(String mealId) async {
    await _vaultRef.doc(mealId).delete();
  }

  /// Check if a meal with the given name already exists in the vault
  Future<bool> mealExists(String name) async {
    final snapshot = await _vaultRef
        .where('name', isEqualTo: name.trim())
        .limit(1)
        .get();
    return snapshot.docs.isNotEmpty;
  }

  /// Approve a staging meal: copy to `vault_meals` then delete from `staging_meals`
  Future<void> approveStagingMeal(CloudMeal stagingMeal) async {
    final batch = _firestore.batch();
    final docRef = _vaultRef.doc(stagingMeal.id);

    final approvedMeal = stagingMeal.copyWith(
      status: 'approved',
      updatedAt: DateTime.now(),
    );

    // The vault is world-readable; the proposer's UID must not follow the
    // meal into it.
    final mealMap = approvedMeal.toMap()..remove('proposedBy');
    batch.set(docRef, mealMap);
    batch.delete(_stagingRef.doc(stagingMeal.id));

    await batch.commit();
  }

  /// Reject / delete a staging meal
  Future<void> rejectStagingMeal(String stagingId) async {
    await _stagingRef.doc(stagingId).delete();
  }

  /// Upload image bytes to Cloudinary and return the optimized download URL
  Future<String?> uploadMealImage(Uint8List bytes, String fileName) async {
    try {
      const cloudName = 'bzd1vjrs';
      const uploadPreset = 'daily meal';

      final uri = Uri.parse(
        'https://api.cloudinary.com/v1_1/$cloudName/image/upload',
      );
      final request = http.MultipartRequest('POST', uri)
        ..fields['upload_preset'] = uploadPreset
        ..files.add(
          http.MultipartFile.fromBytes(
            'file',
            bytes,
            filename: fileName.isEmpty ? 'meal.jpg' : fileName,
          ),
        );

      final streamedResponse = await request.send();
      final response = await http.Response.fromStream(streamedResponse);

      if (response.statusCode == 200) {
        final data = jsonDecode(response.body) as Map<String, dynamic>;
        String secureUrl = data['secure_url'] as String;

        // Auto-optimize delivery using Cloudinary AI format & quality
        if (secureUrl.contains('/upload/')) {
          secureUrl = secureUrl.replaceFirst(
            '/upload/',
            '/upload/f_auto,q_auto/',
          );
        }
        return secureUrl;
      } else {
        throw Exception(
          'Cloudinary error (${response.statusCode}): ${response.body}',
        );
      }
    } catch (e) {
      throw Exception('فشل رفع الصورة: $e');
    }
  }

  /// Deduplicate vault meals by meal name.
  /// Keeps 1 unique document per meal name (prioritizing starter meals or earliest created).
  /// Deletes all surplus duplicates in batched writes.
  Future<int> deduplicateVaultMeals() async {
    final snapshot = await _vaultRef.get();
    if (snapshot.docs.isEmpty) return 0;

    // Group documents by normalized name (trimmed, lowercased)
    final Map<String, List<QueryDocumentSnapshot<Map<String, dynamic>>>>
    grouped = {};
    for (final doc in snapshot.docs) {
      final name = (doc.data()['name'] as String? ?? '').trim().toLowerCase();
      if (name.isEmpty) continue;
      grouped.putIfAbsent(name, () => []).add(doc);
    }

    final List<String> docIdsToDelete = [];

    for (final entry in grouped.entries) {
      final docs = entry.value;
      if (docs.length <= 1) continue;

      // Sort so the preferred one is first:
      // 1. isStarterMeal == true first
      // 2. Earliest createdAt
      docs.sort((a, b) {
        final aStarter = (a.data()['isStarterMeal'] as bool? ?? false) ? 1 : 0;
        final bStarter = (b.data()['isStarterMeal'] as bool? ?? false) ? 1 : 0;
        if (aStarter != bStarter) {
          return bStarter.compareTo(aStarter);
        }
        final aCreated = a.data()['createdAt'] as String? ?? '';
        final bCreated = b.data()['createdAt'] as String? ?? '';
        return aCreated.compareTo(bCreated);
      });

      // Keep docs[0], delete all remaining duplicate documents
      for (var i = 1; i < docs.length; i++) {
        docIdsToDelete.add(docs[i].id);
      }
    }

    if (docIdsToDelete.isEmpty) return 0;

    await _deleteInChunks(_vaultRef, docIdsToDelete);
    return docIdsToDelete.length;
  }

  /// Canonical meal comparator delegating to [DuplicatePairCandidate.compareCanonicalMeals].
  static int compareCanonicalMeals(CloudMeal a, CloudMeal b) =>
      DuplicatePairCandidate.compareCanonicalMeals(a, b);

  /// Calculates number of batch commits required for [totalIds] given [batchSize].
  static int calculateBatchCount(int totalIds, {int batchSize = _writesPerCommit}) =>
      totalIds == 0 ? 0 : (totalIds + batchSize - 1) ~/ batchSize;

  /// Pure candidate detection pipeline without Firestore network dependencies.
  static List<DuplicatePairCandidate> detectCandidatesPure({
    required List<CloudMeal> meals,
    required Set<String> ignoredKeys,
    double threshold = 0.88,
    bool checkById = false,
  }) {
    final List<DuplicatePairCandidate> candidates = [];
    final n = meals.length;
    for (var i = 0; i < n; i++) {
      for (var j = i + 1; j < n; j++) {
        final a = meals[i];
        final b = meals[j];

        final pairKey = IgnoredDuplicate.generatePairKey(a.id, b.id);
        if (ignoredKeys.contains(pairKey)) {
          continue; // Pair acknowledged as distinct by admin
        }

        // Firestore IDs are opaque tokens, so the ID tab matches exact normalized names instead.
        final sim = checkById
            ? (SimilarityEngine.normalizeArabic(a.name) ==
                  SimilarityEngine.normalizeArabic(b.name)
                ? 1.0
                : 0.0)
            : SimilarityEngine.compositeSimilarity(a.name, b.name);

        if (sim >= threshold) {
          candidates.add(DuplicatePairCandidate.resolve(
            mealA: a,
            mealB: b,
            similarity: sim,
          ));
        }
      }
    }

    // Sort descending: highest similarity candidates first
    candidates.sort((a, b) => b.similarity.compareTo(a.similarity));
    return candidates;
  }

  /// One-shot fetch of all ignored duplicate pair keys from Firestore.
  /// Returns a `Set<String>` of document IDs for O(1) in-memory lookups.
  Future<Set<String>> getIgnoredPairKeys() async {
    final snapshot = await _ignoredDuplicatesRef.get();
    return snapshot.docs.map((doc) => doc.id).toSet();
  }

  /// Reactive real-time stream of all ignored duplicate pair keys.
  Stream<Set<String>> streamIgnoredPairKeys() {
    return _ignoredDuplicatesRef.snapshots().map(
      (snapshot) => snapshot.docs.map((doc) => doc.id).toSet(),
    );
  }

  /// Persistently marks a candidate pair as ignored in Firestore.
  /// Document ID is the deterministic symmetric pairKey `${min(idA, idB)}_${max(idA, idB)}`.
  Future<void> ignoreDuplicatePair({
    required CloudMeal mealA,
    required CloudMeal mealB,
    required double similarity,
    String? adminId,
  }) async {
    final pairKey = IgnoredDuplicate.generatePairKey(mealA.id, mealB.id);
    final isFirstSmaller = mealA.id.compareTo(mealB.id) <= 0;
    final m1 = isFirstSmaller ? mealA : mealB;
    final m2 = isFirstSmaller ? mealB : mealA;

    await _ignoredDuplicatesRef.doc(pairKey).set({
      'pairKey': pairKey,
      'mealId1': m1.id,
      'mealId2': m2.id,
      'meal1Name': m1.name,
      'meal2Name': m2.name,
      'similarity': similarity,
      'ignoredAt': FieldValue.serverTimestamp(),
      if (adminId != null && adminId.trim().isNotEmpty)
        'ignoredBy': adminId.trim(),
    });
  }

  /// Unignores a pair by removing its document from `ignored_duplicates`.
  Future<void> unignoreDuplicatePair(String pairKey) async {
    await _ignoredDuplicatesRef.doc(pairKey).delete();
  }

  /// Scans vault meals for similarity >= [threshold] and returns candidate pairs.
  ///
  /// Ignored pairs are filtered out in O(1) time using [preloadedIgnoredKeys]
  /// or by fetching keys once from Firestore via [getIgnoredPairKeys].
  ///
  /// Returned candidates are resolved into canonical form (original vs duplicate)
  /// and sorted in descending order of similarity score.
  Future<List<DuplicatePairCandidate>> detectDuplicateCandidates({
    List<CloudMeal>? preloadedMeals,
    Set<String>? preloadedIgnoredKeys,
    double threshold = 0.88,
    bool checkById = false,
  }) async {
    List<CloudMeal> meals;
    if (preloadedMeals != null) {
      meals = preloadedMeals;
    } else {
      final snapshot = await _vaultRef.get();
      meals = snapshot.docs
          .map((doc) => CloudMeal.fromMap(doc.data(), doc.id))
          .toList();
    }

    final ignoredKeys = preloadedIgnoredKeys ?? await getIgnoredPairKeys();
    return detectCandidatesPure(
      meals: meals,
      ignoredKeys: ignoredKeys,
      threshold: threshold,
      checkById: checkById,
    );
  }

  /// Batch deletes a list of duplicate meals from the vault.
  /// De-duplicates input IDs and executes chunked commits of 8 writes per batch
  /// using the existing [_deleteInChunks] engine.
  ///
  /// Returns the number of unique documents deleted.
  Future<int> deleteDuplicateMealsBatch(List<String> duplicateIds) async {
    if (duplicateIds.isEmpty) return 0;
    final uniqueIds = duplicateIds.toSet().toList();
    await _deleteInChunks(_vaultRef, uniqueIds);
    return uniqueIds.length;
  }

  CollectionReference<Map<String, dynamic>> get _notificationsRef =>
      _firestore.collection('admin_notifications');

  /// Stream all notifications from `admin_notifications`, newest first
  Stream<List<Map<String, dynamic>>> getNotifications() {
    return _notificationsRef
        .orderBy('sentAt', descending: true)
        .snapshots()
        .map((snapshot) {
          return snapshot.docs
              .map((doc) => <String, dynamic>{...doc.data(), 'id': doc.id})
              .toList();
        });
  }

  /// Broadcast a new notification, stamped with the server's clock.
  /// [route] is the in-app destination the mobile app opens when the user taps
  /// the notification; it defaults to the home screen. [segment] says who the
  /// app announces it to by how long they have been cooking — the app has no
  /// push channel, so it is still the next app open that decides. It always
  /// travels: `firestore.rules` closes the write on a segment outside its
  /// contract.
  Future<void> sendNotification({
    required String type,
    required String titleAr,
    required String titleEn,
    required String messageAr,
    required String messageEn,
    required String sentBy,
    required Map<String, dynamic> segment,
    String route = '/',
  }) async {
    final docRef = _notificationsRef.doc();
    await docRef.set({
      'id': docRef.id,
      'type': type,
      'titleAr': titleAr,
      'titleEn': titleEn,
      'messageAr': messageAr,
      'messageEn': messageEn,
      'route': route,
      'segment': segment,
      'sentAt': FieldValue.serverTimestamp(),
      'sentBy': sentBy,
    });
  }

  /// Delete a notification from `admin_notifications`
  Future<void> deleteNotification(String id) async {
    await _notificationsRef.doc(id).delete();
  }

  /// Total number of notifications stored in `admin_notifications`
  Future<int> getNotificationCount() async {
    final aggregate = await _notificationsRef.count().get();
    return aggregate.count ?? 0;
  }

  CollectionReference<Map<String, dynamic>> get _draftsRef =>
      _firestore.collection('admin_notification_drafts');

  /// Stream saved drafts, newest first. Kept in its own collection so a draft
  /// can never reach the mobile app, which reads `admin_notifications`.
  Stream<List<Map<String, dynamic>>> getDrafts() {
    return _draftsRef.orderBy('updatedAt', descending: true).snapshots().map((
      snapshot,
    ) {
      return snapshot.docs
          .map((doc) => <String, dynamic>{...doc.data(), 'id': doc.id})
          .toList();
    });
  }

  /// Save a draft, creating it when [id] is null and overwriting it otherwise.
  /// Returns the document id so the compose tab can keep editing one record.
  /// The [segment] travels with the copy so a reopened draft resumes the same
  /// targeting, not just the same text.
  Future<String> saveDraft({
    String? id,
    required String type,
    required String titleAr,
    required String titleEn,
    required String messageAr,
    required String messageEn,
    required String savedBy,
    required Map<String, dynamic> segment,
    String route = '/',
  }) async {
    final body = <String, dynamic>{
      'type': type,
      'titleAr': titleAr,
      'titleEn': titleEn,
      'messageAr': messageAr,
      'messageEn': messageEn,
      'route': route,
      'segment': segment,
      'savedBy': savedBy,
      'updatedAt': FieldValue.serverTimestamp(),
    };

    if (id == null) {
      final docRef = _draftsRef.doc();
      await docRef.set({
        ...body,
        'id': docRef.id,
        'createdAt': FieldValue.serverTimestamp(),
      });
      return docRef.id;
    }

    await _draftsRef.doc(id).update(body);
    return id;
  }

  /// Drop a draft once it has been sent or discarded.
  Future<void> deleteDraft(String id) async {
    await _draftsRef.doc(id).delete();
  }
}
