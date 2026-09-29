import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../data/admin_auth_service.dart';
import '../data/admin_security_service.dart';
import 'admin_auth_screen.dart';
import 'admin_dashboard_screen.dart';

class AdminRootScreen extends ConsumerStatefulWidget {
  const AdminRootScreen({super.key});

  @override
  ConsumerState<AdminRootScreen> createState() => _AdminRootScreenState();
}

class _AdminRootScreenState extends ConsumerState<AdminRootScreen> {
  String? _unauthorizedError;

  @override
  Widget build(BuildContext context) {
    final authState = ref.watch(authStateProvider);

    return authState.when(
      loading: () => const Scaffold(
        body: Center(child: CircularProgressIndicator()),
      ),
      error: (err, _) => Scaffold(
        body: Center(child: Text('خطأ في التحقق من تسجيل الدخول: $err')),
      ),
      data: (user) {
        if (user == null) {
          return AdminAuthScreen(initialErrorMessage: _unauthorizedError);
        }

        final adminStatusAsync = ref.watch(isAdminProvider(user.email));

        return adminStatusAsync.when(
          loading: () => const Scaffold(
            body: Center(child: CircularProgressIndicator()),
          ),
          error: (err, _) {
            const unauthorizedMsg =
                'غير مصرح لك بالوصول إلى لوحة التحكم كمسؤول. تم تسجيل الخروج تلقائياً.';
            _unauthorizedError = unauthorizedMsg;
            WidgetsBinding.instance.addPostFrameCallback((_) {
              ref.read(adminAuthServiceProvider).signOut();
            });
            return const AdminAuthScreen(
              initialErrorMessage: unauthorizedMsg,
            );
          },
          data: (isAuthorized) {
            if (!isAuthorized) {
              const unauthorizedMsg =
                  'غير مصرح لك بالوصول إلى لوحة التحكم كمسؤول. تم تسجيل الخروج تلقائياً.';
              _unauthorizedError = unauthorizedMsg;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                ref.read(adminAuthServiceProvider).signOut();
              });
              return const AdminAuthScreen(
                initialErrorMessage: unauthorizedMsg,
              );
            }

            _unauthorizedError = null;
            return const AdminDashboardScreen();
          },
        );
      },
    );
  }
}
