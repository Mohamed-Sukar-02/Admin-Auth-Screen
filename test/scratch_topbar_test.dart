// SCRATCH golden harness — delete after reviewing the PNGs.
import 'dart:async';
import 'dart:io';
import 'dart:typed_data';

import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:daily_meal/core/database/tables/app_settings_table.dart';
import 'package:daily_meal/core/theme/app_theme.dart';
import 'package:daily_meal/features/admin/data/admin_auth_service.dart';
import 'package:daily_meal/features/admin/data/admin_security_service.dart';
import 'package:daily_meal/features/admin/data/models/cloud_meal.dart';
import 'package:daily_meal/features/admin/data/vault_admin_repository.dart';
import 'package:daily_meal/features/admin/presentation/admin_dashboard_screen.dart';
import 'package:daily_meal/features/settings/data/theme_preference_store.dart';

class _FakeThemeStore implements ThemePreferenceStore {
  AppThemeModePreference mode = AppThemeModePreference.dark;
  final _changes = StreamController<AppThemeModePreference>.broadcast();

  @override
  Stream<AppThemeModePreference> watchThemeMode() async* {
    yield mode;
    yield* _changes.stream;
  }

  @override
  Future<void> setThemeMode(AppThemeModePreference mode) async {
    this.mode = mode;
    _changes.add(mode);
  }
}

Future<void> _loadFonts() async {
  const families = {
    'IBM Plex Sans Arabic': [
      'IBMPlexSansArabic-Regular',
      'IBMPlexSansArabic-Medium',
      'IBMPlexSansArabic-SemiBold',
      'IBMPlexSansArabic-Bold',
    ],
    'Inter': [
      'Inter-Regular',
      'Inter-Medium',
      'Inter-SemiBold',
      'Inter-Bold',
    ],
  };
  for (final entry in families.entries) {
    for (final file in entry.value) {
      final bytes = File('google_fonts/$file.ttf').readAsBytesSync();
      final loader = FontLoader(entry.key)
        ..addFont(Future.value(ByteData.view(bytes.buffer)));
      await loader.load();
    }
  }
}

Future<void> _pump(WidgetTester tester, {required Size size}) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1.0;
  addTearDown(tester.view.resetPhysicalSize);
  addTearDown(tester.view.resetDevicePixelRatio);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        authStateProvider.overrideWith((ref) => Stream<User?>.empty()),
        adminRoleProvider.overrideWith((ref, arg) => Future.value('super_admin')),
        themePreferenceStoreProvider.overrideWithValue(_FakeThemeStore()),
        vaultMealsStreamProvider.overrideWith(
          (ref) => Stream.value(const <CloudMeal>[]),
        ),
        stagingMealsStreamProvider.overrideWith(
          (ref) => Stream.value(const <CloudMeal>[]),
        ),
        adminNotificationsStreamProvider.overrideWith(
          (ref) => Stream.value(const <Map<String, dynamic>>[]),
        ),
        adminDraftsStreamProvider.overrideWith(
          (ref) => Stream.value(const <Map<String, dynamic>>[]),
        ),
      ],
      child: MaterialApp(
        themeMode: ThemeMode.dark,
        theme: AppTheme.lightTheme,
        darkTheme: AppTheme.darkTheme,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: const Scaffold(body: AdminDashboardScreen()),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _go(WidgetTester tester, String label) async {
  await tester.tap(find.text(label).first);
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _shoot(WidgetTester tester, String name) async {
  await expectLater(
    find.byType(MaterialApp),
    matchesGoldenFile('scratch/goldens/$name.png'),
  );
}

bool hasVaultSearch(WidgetTester tester) => tester
    .widgetList<TextField>(find.byType(TextField))
    .any((f) => f.decoration?.hintText == 'ابحث عن أكلة في الخزنة...');

void main() {
  setUpAll(_loadFonts);

  testWidgets('the vault page keeps the search, the rest do not', (
    tester,
  ) async {
    await _pump(tester, size: const Size(1440, 900));
    expect(hasVaultSearch(tester), isTrue);
    await _shoot(tester, 'ai3_vault_page');

    await _go(tester, 'الإشعارات');
    expect(hasVaultSearch(tester), isFalse);
    await _shoot(tester, 'ai3_notifications_page');
  });
}
