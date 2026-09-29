/// Application-wide constants for 'أكلة النهاردة' (Daily Meal)
class AppConstants {
  AppConstants._();

  static const String appName = 'أكلة النهاردة';
  static const String appSubtitle = 'اقتراحات يومية ذكية لوجبات البيت المصري';

  // Navigation routes
  static const String routeHome = '/';
  static const String routeVault = '/vault';
  static const String routeHistory = '/history';
  static const String routeSettings = '/settings';

  // Default values
  static const int defaultCooldownDays = 14;
  static const int minCooldownDays = 1;
  static const int maxCooldownDays = 60;
  static const int defaultNotificationHour = 12;
  static const int defaultNotificationMinute = 0;
  static const int maxRecommendations = 3;
  static const int minSpinWheelCandidates = 2;
}
