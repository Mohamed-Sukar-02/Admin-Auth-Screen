import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'admin_security_service.dart';

final adminAuthProvider = Provider<AdminAuthService>((ref) {
  final securityService = ref.watch(adminSecurityServiceProvider);
  return AdminAuthService(
    FirebaseAuth.instance,
    adminSecurityService: securityService,
  );
});

final adminAuthServiceProvider = adminAuthProvider;

final authStateProvider = StreamProvider<User?>((ref) {
  final authService = ref.watch(adminAuthProvider);
  return authService.authStateChanges();
});

/// Exception thrown when an authenticated account is not authorized in Firestore `/admins` collection.
class AdminUnauthorizedException implements Exception {
  final String message;
  const AdminUnauthorizedException([
    this.message = 'البريد الإلكتروني غير مصرح له بالدخول كمسؤول.',
  ]);

  @override
  String toString() => message;
}

class AdminAuthService {
  final FirebaseAuth _auth;
  final AdminSecurityService _securityService;

  AdminAuthService(this._auth, {AdminSecurityService? adminSecurityService})
    : _securityService =
          adminSecurityService ??
          AdminSecurityService(FirebaseFirestore.instance);

  Stream<User?> authStateChanges() => _auth.authStateChanges();

  User? get currentUser => _auth.currentUser;

  Future<UserCredential> signInWithEmail(String email, String password) async {
    final credential = await _auth.signInWithEmailAndPassword(
      email: email.trim(),
      password: password.trim(),
    );
    final user = credential.user;
    final isAuthorized = await _securityService.isEmailAdmin(user?.email);
    if (!isAuthorized) {
      await _auth.signOut();
      throw const AdminUnauthorizedException(
        'البريد الإلكتروني غير مصرح له بالدخول كمسؤول.',
      );
    }
    // The account demonstrably exists now, which is what the roster was never
    // able to claim at the moment it was granted.
    await _securityService.stampLogin(user?.email);
    return credential;
  }

  Future<UserCredential> signInWithGoogle() async {
    final googleProvider = GoogleAuthProvider();
    final credential = await _auth.signInWithPopup(googleProvider);
    final user = credential.user;
    final isAuthorized = await _securityService.isEmailAdmin(user?.email);
    if (!isAuthorized) {
      await _auth.signOut();
      throw const AdminUnauthorizedException(
        'البريد الإلكتروني غير مصرح له بالدخول كمسؤول.',
      );
    }
    await _securityService.stampLogin(user?.email);
    return credential;
  }

  Future<void> signOut() async {
    await _auth.signOut();
  }
}
