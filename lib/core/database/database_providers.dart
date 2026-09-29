import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app_database.dart';

/// Singleton Drift AppDatabase provider.
/// Automatically closes the database connection on provider disposal.
final databaseProvider = Provider<AppDatabase>((ref) {
  final db = AppDatabase();
  ref.onDispose(() => db.close());
  return db;
});

/// Exposes MealsDao from the database instance.
final mealsDaoProvider = Provider<MealsDao>((ref) {
  return ref.watch(databaseProvider).mealsDao;
});

/// Exposes MealHistoryDao from the database instance.
final mealHistoryDaoProvider = Provider<MealHistoryDao>((ref) {
  return ref.watch(databaseProvider).mealHistoryDao;
});

/// Exposes AppSettingsDao from the database instance.
final appSettingsDaoProvider = Provider<AppSettingsDao>((ref) {
  return ref.watch(databaseProvider).appSettingsDao;
});
