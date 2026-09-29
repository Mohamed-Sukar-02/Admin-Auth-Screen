import 'package:drift/drift.dart';
import '../app_database.dart';

part 'meals_dao.g.dart';

@DriftAccessor(tables: [Meals])
class MealsDao extends DatabaseAccessor<AppDatabase> with _$MealsDaoMixin {
  MealsDao(super.db);

  /// Watch all meals in the vault, ordered alphabetically by name, then by id DESC
  Stream<List<Meal>> watchAllMeals() {
    return (select(meals)
          ..orderBy([
            (t) => OrderingTerm.asc(t.name),
            (t) => OrderingTerm.desc(t.id),
          ]))
        .watch();
  }

  /// Watch a single meal by primary key ID
  Stream<Meal?> watchMealById(int id) {
    return (select(meals)..where((t) => t.id.equals(id))).watchSingleOrNull();
  }

  /// Watch favorite meals
  Stream<List<Meal>> watchFavorites() {
    return (select(meals)
          ..where((t) => t.isFavorite.equals(true))
          ..orderBy([
            (t) => OrderingTerm.asc(t.name),
            (t) => OrderingTerm.desc(t.id),
          ]))
        .watch();
  }

  /// Watch meals matching a search query string
  Stream<List<Meal>> watchSearchMeals(String query) {
    final clean = query.trim();
    if (clean.isEmpty) return watchAllMeals();

    return (select(meals)
          ..where((t) => t.name.like('%$clean%'))
          ..orderBy([
            (t) => OrderingTerm.asc(t.name),
            (t) => OrderingTerm.desc(t.id),
          ]))
        .watch();
  }

  /// Watch meals matching multiple optional tag filters
  Stream<List<Meal>> watchFilterByTag({
    ProteinType? proteinType,
    CarbsType? carbsType,
    MealCategory? category,
    bool? isFridaySpecial,
    bool? isBudgetFriendly,
    bool? isFavorite,
    int? maxPrepTimeMinutes,
  }) {
    return _buildFilteredQuery(
      proteinType: proteinType,
      carbsType: carbsType,
      category: category,
      isFridaySpecial: isFridaySpecial,
      isBudgetFriendly: isBudgetFriendly,
      isFavorite: isFavorite,
      maxPrepTimeMinutes: maxPrepTimeMinutes,
    ).watch();
  }

  /// One-shot query to fetch all meals
  Future<List<Meal>> getAllMeals() {
    return (select(meals)
          ..orderBy([
            (t) => OrderingTerm.asc(t.name),
            (t) => OrderingTerm.desc(t.id),
          ]))
        .get();
  }

  /// Fetch a single meal by its primary key ID
  Future<Meal?> getMealById(int id) {
    return (select(meals)..where((t) => t.id.equals(id))).getSingleOrNull();
  }

  /// Search meals by name query
  Future<List<Meal>> searchMeals(String query) {
    final clean = query.trim();
    if (clean.isEmpty) return getAllMeals();

    return (select(meals)
          ..where((t) => t.name.like('%$clean%'))
          ..orderBy([
            (t) => OrderingTerm.asc(t.name),
            (t) => OrderingTerm.desc(t.id),
          ]))
        .get();
  }

  /// Filter meals by multiple optional criteria
  Future<List<Meal>> filterByTag({
    ProteinType? proteinType,
    CarbsType? carbsType,
    MealCategory? category,
    bool? isFridaySpecial,
    bool? isBudgetFriendly,
    bool? isFavorite,
    int? maxPrepTimeMinutes,
  }) {
    return _buildFilteredQuery(
      proteinType: proteinType,
      carbsType: carbsType,
      category: category,
      isFridaySpecial: isFridaySpecial,
      isBudgetFriendly: isBudgetFriendly,
      isFavorite: isFavorite,
      maxPrepTimeMinutes: maxPrepTimeMinutes,
    ).get();
  }

  /// Insert a new meal into the vault
  Future<int> insertMeal(MealsCompanion meal) {
    if (meal.name.present) {
      if (meal.name.value.trim().isEmpty) {
        throw ArgumentError('Meal name cannot be empty or whitespace');
      }
    }
    if (meal.prepTime.present) {
      if (meal.prepTime.value <= 0) {
        throw ArgumentError('Prep time must be a positive integer');
      }
    }
    return into(meals).insert(meal);
  }

  /// Batch insert meals
  Future<void> insertMealsBatch(List<MealsCompanion> mealCompanions) {
    return batch((b) {
      b.insertAll(meals, mealCompanions);
    });
  }

  /// Replace / update an existing meal
  Future<bool> updateMeal(Meal meal) {
    return update(meals).replace(meal.copyWith(updatedAt: DateTime.now()));
  }

  /// Update meal via companion
  Future<int> updateMealCompanion(int id, MealsCompanion companion) {
    return (update(meals)..where((t) => t.id.equals(id)))
        .write(companion.copyWith(updatedAt: Value(DateTime.now())));
  }

  /// Delete a meal by ID (triggers KeyAction.setNull on MealHistory)
  Future<int> deleteMeal(int id) {
    return (delete(meals)..where((t) => t.id.equals(id))).go();
  }

  /// Clear all meals
  Future<int> deleteAllMeals() {
    return delete(meals).go();
  }

  /// Toggle favorite status of a meal
  Future<void> toggleFavorite(int id, [bool? currentStatus]) async {
    bool newStatus;
    if (currentStatus != null) {
      newStatus = !currentStatus;
    } else {
      final meal = await getMealById(id);
      if (meal == null) return;
      newStatus = !meal.isFavorite;
    }

    await (update(meals)..where((t) => t.id.equals(id))).write(
      MealsCompanion(
        isFavorite: Value(newStatus),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  SimpleSelectStatement<$MealsTable, Meal> _buildFilteredQuery({
    String? query,
    ProteinType? proteinType,
    CarbsType? carbsType,
    MealCategory? category,
    bool? isFridaySpecial,
    bool? isBudgetFriendly,
    bool? isFavorite,
    int? maxPrepTimeMinutes,
  }) {
    final statement = select(meals);
    statement.where((t) {
      final predicates = <Expression<bool>>[];
      if (query != null && query.trim().isNotEmpty) {
        predicates.add(t.name.like('%${query.trim()}%'));
      }
      if (proteinType != null) {
        predicates.add(t.proteinType.equalsValue(proteinType));
      }
      if (carbsType != null) {
        predicates.add(t.carbsType.equalsValue(carbsType));
      }
      if (category != null) {
        predicates.add(t.category.equalsValue(category));
      }
      if (isFridaySpecial != null) {
        predicates.add(t.isFridaySpecial.equals(isFridaySpecial));
      }
      if (isBudgetFriendly != null) {
        predicates.add(t.isBudgetFriendly.equals(isBudgetFriendly));
      }
      if (isFavorite != null) {
        predicates.add(t.isFavorite.equals(isFavorite));
      }
      if (maxPrepTimeMinutes != null) {
        predicates.add(t.prepTime.isSmallerOrEqualValue(maxPrepTimeMinutes));
      }

      if (predicates.isEmpty) return const Constant(true);
      return Expression.and(predicates);
    });

    statement.orderBy([
      (t) => OrderingTerm.asc(t.name),
      (t) => OrderingTerm.desc(t.id),
    ]);
    return statement;
  }
}
