import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../features/admin/presentation/admin_root_screen.dart';
import '../../features/admin/presentation/admin_forgot_password_screen.dart';

final rootNavigatorKey = GlobalKey<NavigatorState>(debugLabel: 'rootNav');

final appRouterProvider = Provider<GoRouter>((ref) {
  return GoRouter(
    navigatorKey: rootNavigatorKey,
    initialLocation: '/admin',
    routes: [
      GoRoute(
        path: '/admin',
        name: 'admin',
        pageBuilder: (context, state) => const NoTransitionPage(
          child: AdminRootScreen(),
        ),
      ),
      GoRoute(
        path: '/admin/forgot-password',
        name: 'admin_forgot_password',
        pageBuilder: (context, state) {
          final email = state.extra as String?;
          return NoTransitionPage(
            child: AdminForgotPasswordScreen(initialEmail: email),
          );
        },
      ),
    ],
  );
});
