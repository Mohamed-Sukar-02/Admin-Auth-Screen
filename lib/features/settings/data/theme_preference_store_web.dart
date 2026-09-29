import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:web/web.dart' as web;

import '../../../core/database/app_database.dart';
import 'theme_preference_store.dart';

ThemePreferenceStore createThemePreferenceStore(Ref ref) =>
    const LocalStorageThemePreferenceStore();

const _storageKey = 'daily-meal.theme-mode';

final _edits = StreamController<AppThemeModePreference>.broadcast();

AppThemeModePreference _stored() {
  final raw = web.window.localStorage.getItem(_storageKey);
  return AppThemeModePreference.values.firstWhere(
    (mode) => mode.name == raw,
    orElse: () => AppThemeModePreference.system,
  );
}

class LocalStorageThemePreferenceStore implements ThemePreferenceStore {
  const LocalStorageThemePreferenceStore();

  @override
  Stream<AppThemeModePreference> watchThemeMode() async* {
    yield _stored();
    yield* _edits.stream;
  }

  @override
  Future<void> setThemeMode(AppThemeModePreference mode) async {
    web.window.localStorage.setItem(_storageKey, mode.name);
    _edits.add(mode);
  }
}
