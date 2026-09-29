import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class AdminSystemConfigRepository {
  final FirebaseFirestore _firestore;

  AdminSystemConfigRepository(this._firestore);

  DocumentReference<Map<String, dynamic>> get _configRef =>
      _firestore.collection('admin_config').doc('system_defaults');

  Stream<Map<String, dynamic>?> streamSystemConfig() {
    return _configRef.snapshots().map((snapshot) => snapshot.data());
  }

  Future<void> updateSystemConfig({
    int? cooldownDays,
    String? minAppVersion,
    String? announcement,
    bool? maintenanceMode,
  }) async {
    final Map<String, dynamic> updates = {};
    if (cooldownDays != null) updates['cooldownDays'] = cooldownDays;
    if (minAppVersion != null) updates['minAppVersion'] = minAppVersion;
    if (announcement != null) updates['announcement'] = announcement;
    if (maintenanceMode != null) updates['maintenanceMode'] = maintenanceMode;
    updates['updatedAt'] = FieldValue.serverTimestamp();

    await _configRef.set(updates, SetOptions(merge: true));
  }
}

final adminSystemConfigRepositoryProvider =
    Provider<AdminSystemConfigRepository>((ref) {
      return AdminSystemConfigRepository(FirebaseFirestore.instance);
    });

final systemConfigStreamProvider =
    StreamProvider.autoDispose<Map<String, dynamic>?>((ref) {
      return ref
          .watch(adminSystemConfigRepositoryProvider)
          .streamSystemConfig();
    });
