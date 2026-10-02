import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:daily_meal/features/admin/presentation/admin_dashboard_screen.dart';

void main() {
  testWidgets('Test dashboard narrow layout', (WidgetTester tester) async {
    tester.view.physicalSize = const Size(400, 800);
    tester.view.devicePixelRatio = 1.0;

    FlutterError.onError = (FlutterErrorDetails details) {
      print('FLUTTER ERROR: ${details.exception}');
    };

    try {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(
            home: Scaffold(body: AdminDashboardScreen()),
          ),
        ),
      );
      await tester.pumpAndSettle(const Duration(milliseconds: 100));
    } catch (e) {
      print('CAUGHT: $e');
    }
  });
}
