import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../../core/database/database_providers.dart';
import 'theme_preference_store.dart';

ThemePreferenceStore createThemePreferenceStore(Ref ref) =>
    DriftThemePreferenceStore(ref.watch(appSettingsDaoProvider));

class DriftThemePreferenceStore implements ThemePreferenceStore {
  DriftThemePreferenceStore(this._dao);

  final AppSettingsDao _dao;

  @override
  Stream<AppThemeModePreference> watchThemeMode() =>
      _dao.watchSettings().map((settings) => settings.themeMode);

  @override
  Future<void> setThemeMode(AppThemeModePreference mode) =>
      _dao.updateThemeMode(mode);
}
