// SCRATCH golden harness — delete after reviewing the PNGs.
import 'dart:io';
import 'dart:typed_data';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:daily_meal/core/theme/app_theme.dart';
import 'package:daily_meal/features/admin/data/ai_provider_repository.dart';
import 'package:daily_meal/features/admin/data/models/ai_provider.dart';
import 'package:daily_meal/features/admin/data/models/cloud_meal.dart';
import 'package:daily_meal/features/admin/data/vault_admin_repository.dart';
import 'package:daily_meal/features/admin/presentation/widgets/ai_assistant_panel.dart';
import 'package:daily_meal/features/admin/presentation/widgets/provider_brand_icons.dart';

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
        activeAiProvidersStreamProvider.overrideWith(
          (ref) => Stream.value([
            const AiProvider(
              id: 'p1',
              name: 'Gemini key',
              provider: 'gemini',
              model: 'gemini-3.7-flash',
              apiKey: 'k',
              endpoint: '',
            ),
          ]),
        ),
        customAiModelsStreamProvider.overrideWith(
          (ref) => Stream.value(const <String, List<String>>{}),
        ),
        vaultMealsStreamProvider.overrideWith(
          (ref) => Stream.value(const <CloudMeal>[]),
        ),
      ],
      child: MaterialApp(
        theme: AppTheme.darkTheme,
        locale: const Locale('ar'),
        supportedLocales: const [Locale('ar'), Locale('en')],
        localizationsDelegates: const [
          GlobalMaterialLocalizations.delegate,
          GlobalWidgetsLocalizations.delegate,
          GlobalCupertinoLocalizations.delegate,
        ],
        home: Scaffold(
          body: SingleChildScrollView(
            padding: const EdgeInsets.all(16),
            child: AiAssistantPanel(onApplyToForm: (_) async => true),
          ),
        ),
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 400));
}

Future<void> _shoot(WidgetTester tester, String name, [Finder? target]) async {
  await expectLater(
    target ?? find.byType(MaterialApp),
    matchesGoldenFile('scratch/goldens/$name.png'),
  );
}

void main() {
  setUpAll(_loadFonts);

  testWidgets('the three provider marks read as their brands', (tester) async {
    tester.view.physicalSize = const Size(360, 140);
    tester.view.devicePixelRatio = 1.0;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: MediaQuery(
          data: const MediaQueryData(),
          child: Material(
            color: const Color(0xFF2B3B31),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceEvenly,
              children: [
                for (final provider in ['gemini', 'groq', 'openrouter'])
                  ProviderBrandIcon(
                    provider: provider,
                    size: 72,
                    color: const Color(0xFFD7DFD1),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
    await _shoot(tester, 'ai2_marks', find.byType(Row));
  });

  testWidgets('assistant panel hugs its content', (tester) async {
    await _pump(tester, size: const Size(798, 900));
    await _shoot(tester, 'ai2_panel_dark');
  });

  testWidgets('model menu opens left to right', (tester) async {
    await _pump(tester, size: const Size(798, 900));
    await tester.tap(find.byType(MenuAnchor));
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 500));
    await _shoot(tester, 'ai2_menu_open');
  });

  testWidgets('long idea grows the capsule', (tester) async {
    await _pump(tester, size: const Size(798, 900));
    final field = tester.widget<TextField>(find.byType(TextField));
    field.controller!.text =
        'قولي فكرة طويلة عن أكلة النهاردة عشان أشوف الحقل بيكبر ولا لأ، '
        'وديت سطر تاني وسطر تالت وعشان أوصل للتلات سطور لازم كلام أطول شوية';
    await tester.pump();
    await _shoot(tester, 'ai2_panel_filled');
  });
}
