import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

/// The roles `firestore.rules` and the dashboard both understand. `admin` is
/// the pre-role spelling, normalised to `editing_admin` on read.
const List<String> adminRoles = [
  'viewing_admin',
  'editing_admin',
  'super_admin',
];

/// Service managing Firestore-backed admin authorization and seeding.
class AdminSecurityService {
  final FirebaseFirestore _firestore;

  AdminSecurityService(this._firestore);

  /// Queries the `/admins/{email.trim().toLowerCase()}` document to verify admin access.
  Future<bool> isEmailAdmin(String? email) async {
    if (email == null) return false;
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return false;

    try {
      final doc = await _firestore.collection('admins').doc(normalized).get();
      return doc.exists;
    } catch (_) {
      return false;
    }
  }

  /// The document id doubles as the grant key the security rules compare
  /// against `request.auth.token.email`, so a stray space or a missing `@`
  /// writes a row that grants nobody and reports success.
  static final RegExp _emailPattern = RegExp(r'^[^@\s]+@[^@\s]+\.[^@\s]+$');

  /// Whether [email] can become a usable grant key. The dashboard gates its
  /// "add" button on this so a typo never writes a row that grants nobody.
  static bool isUsableEmail(String email) =>
      _emailPattern.hasMatch(email.trim().toLowerCase());

  /// Seeds an admin email into the `admins` collection.
  Future<void> seedAdmin({
    required String email,
    String role = 'viewing_admin',
    FirebaseFirestore? firestore,
  }) async {
    final normalized = email.trim().toLowerCase();
    if (!_emailPattern.hasMatch(normalized)) {
      throw const FormatException('Not a valid email address');
    }
    if (!adminRoles.contains(role)) {
      throw ArgumentError.value(role, 'role', 'Unknown admin role');
    }
    final db = firestore ?? _firestore;
    await db.collection('admins').doc(normalized).set({
      'email': email,
      'role': role,
      'createdAt': FieldValue.serverTimestamp(),
    });
    await _recordAudit('add', target: normalized, role: role, db: db);
  }

  /// Streams all admin documents.
  Stream<List<Map<String, dynamic>>> streamAdmins() {
    return _firestore.collection('admins').snapshots().map((snapshot) {
      return snapshot.docs.map((doc) => {'id': doc.id, ...doc.data()}).toList();
    });
  }

  // ---------- audit trail ----------

  static const String auditCollection = 'admin_audit';

  /// Appends one roster change. Best-effort by design: an audit write that is
  /// denied (security rules not deployed yet, offline) must not make the
  /// roster change itself report as failed, because it already succeeded.
  Future<void> _recordAudit(
    String action, {
    required String target,
    String? role,
    FirebaseFirestore? db,
  }) async {
    final actor = FirebaseAuth.instance.currentUser?.email
        ?.trim()
        .toLowerCase();
    try {
      await (db ?? _firestore).collection(auditCollection).add({
        'action': action,
        'target': target,
        if (role != null) 'role': role,
        // The rules require this to be the caller's own address, so the entry
        // cannot be pinned on somebody else.
        'actor': actor ?? '',
        'at': FieldValue.serverTimestamp(),
      });
    } catch (e) {
      debugPrint('admin_audit write skipped ($action $target): $e');
    }
  }

  /// The newest roster changes, newest first.
  Stream<List<Map<String, dynamic>>> streamAuditLog({int limit = 25}) {
    return _firestore
        .collection(auditCollection)
        .orderBy('at', descending: true)
        .limit(limit)
        .snapshots()
        .map(
          (snapshot) => snapshot.docs
              .map((doc) => {'id': doc.id, ...doc.data()})
              .toList(),
        );
  }

  /// Records that this address really did sign in.
  ///
  /// Asking Firebase whether an email has an account is no longer possible from
  /// a client — firebase_auth 6 removed the lookup, and the remaining way needs
  /// a privileged key that cannot ship in a web bundle. A successful sign-in is
  /// therefore the only available proof the address exists, so the roster shows
  /// it as "has signed in" instead of the old unconditional "تم" that also
  /// printed for a typo nobody could ever log in as.
  ///
  /// Best effort: a stamp that fails must not stand between a real admin and
  /// the dashboard.
  Future<void> stampLogin(String? email) async {
    final normalized = email?.trim().toLowerCase() ?? '';
    if (normalized.isEmpty) return;
    try {
      await _firestore.collection('admins').doc(normalized).set({
        'lastSeenAt': FieldValue.serverTimestamp(),
      }, SetOptions(merge: true));
    } catch (e) {
      debugPrint('admins/$normalized activity stamp skipped: $e');
    }
  }

  /// Removes an admin by email.
  Future<void> removeAdmin(String email) async {
    final normalized = email.trim().toLowerCase();
    await _firestore.collection('admins').doc(normalized).delete();
    await _recordAudit('remove', target: normalized);
  }

  /// Fetches the role of the admin (e.g. 'viewing_admin', 'editing_admin' or 'super_admin').
  ///
  /// Pure read. This used to write `super_admin` onto the caller's own document
  /// whenever the collection held no super admin, so deleting or demoting the
  /// last one handed full control to whoever signed in next — and a role lookup
  /// that mutates the roster is not a lookup. Promoting the first super admin
  /// is now a deliberate operation in the Firebase console, which is the only
  /// place it can be safe, because `firestore.rules` restricts every write to
  /// this collection to an existing super admin.
  Future<String?> getAdminRole(String? email) async {
    if (email == null) return null;
    final normalized = email.trim().toLowerCase();
    if (normalized.isEmpty) return null;

    try {
      final doc = await _firestore.collection('admins').doc(normalized).get();
      if (!doc.exists) return null;

      final role = doc.data()?['role'] as String?;
      if (role == 'admin') return 'editing_admin'; // Legacy map
      return role ?? 'viewing_admin';
    } catch (_) {
      return null;
    }
  }

  /// Updates an admin's role.
  Future<void> setAdminRole(String email, String role) async {
    if (!adminRoles.contains(role)) {
      throw ArgumentError.value(role, 'role', 'Unknown admin role');
    }
    final normalized = email.trim().toLowerCase();
    await _firestore.collection('admins').doc(normalized).update({
      'role': role,
    });
    await _recordAudit('set_role', target: normalized, role: role);
  }
}

/// Provider for [AdminSecurityService] using Firestore singleton.
final adminSecurityServiceProvider = Provider<AdminSecurityService>((ref) {
  return AdminSecurityService(FirebaseFirestore.instance);
});

/// Riverpod FutureProvider checking if the given email belongs to an authorized admin.
final isAdminProvider = FutureProvider.family<bool, String?>((
  ref,
  email,
) async {
  final service = ref.watch(adminSecurityServiceProvider);
  return service.isEmailAdmin(email);
});

/// Riverpod FutureProvider fetching the role of the given admin email.
final adminRoleProvider = FutureProvider.family<String?, String?>((
  ref,
  email,
) async {
  final service = ref.watch(adminSecurityServiceProvider);
  return service.getAdminRole(email);
});
