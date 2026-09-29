import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import 'theme_preference_store_io.dart'
    if (dart.library.js_interop) 'theme_preference_store_web.dart' as platform;

/// Keeps the display-mode choice alive across restarts and reloads.
abstract class ThemePreferenceStore {
  Stream<AppThemeModePreference> watchThemeMode();

  Future<void> setThemeMode(AppThemeModePreference mode);
}

/// Mobile reads the choice from the Drift settings row. The hosted admin site
/// cannot: Drift's web executor needs a SQLite WASM bundle the site does not
/// ship, so opening `AppDatabase` in a browser throws and every setting would
/// be frozen at its default — leaving the site locked to whatever the operating
/// system reports. The web build keeps the choice in `localStorage` instead.
final themePreferenceStoreProvider =
    Provider<ThemePreferenceStore>(platform.createThemePreferenceStore);
