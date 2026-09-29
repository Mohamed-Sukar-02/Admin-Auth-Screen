// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'meal_history_dao.dart';

// ignore_for_file: type=lint
mixin _$MealHistoryDaoMixin on DatabaseAccessor<AppDatabase> {
  $MealsTable get meals => attachedDatabase.meals;
  $MealHistoryTable get mealHistory => attachedDatabase.mealHistory;
  MealHistoryDaoManager get managers => MealHistoryDaoManager(this);
}

class MealHistoryDaoManager {
  final _$MealHistoryDaoMixin _db;
  MealHistoryDaoManager(this._db);
  $$MealsTableTableManager get meals =>
      $$MealsTableTableManager(_db.attachedDatabase, _db.meals);
  $$MealHistoryTableTableManager get mealHistory =>
      $$MealHistoryTableTableManager(_db.attachedDatabase, _db.mealHistory);
}
