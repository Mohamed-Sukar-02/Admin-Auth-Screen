import 'package:flutter/material.dart';

class AppStrings {
  final Locale locale;

  const AppStrings(this.locale);

  bool get isEn => locale.languageCode == 'en';

  String get appName => isEn ? 'Daily Meal' : 'أكلة النهاردة';
  String get appSubtitle => isEn
      ? 'Smart daily meal suggestions for your home'
      : 'اقتراحات يومية ذكية لوجبات البيت المصري';

  // Navigation
  String get navHome => isEn ? 'Home' : 'الرئيسية';
  String get navVault => isEn ? 'Vault' : 'خزانة الأكلات';
  String get navHistory => isEn ? 'History' : 'السجل';
  String get navSettings => isEn ? 'Settings' : 'الإعدادات';

  // Settings
  String get languageSettings => isEn ? 'Language' : 'اللغة';
  String get cooldownSettings =>
      isEn ? 'Cooldown Period' : 'فترة استبعاد الأكلات (Cooldown)';
  String get cooldownDesc => isEn
      ? 'Duration to exclude a cooked meal from suggestions.'
      : 'المدة التي تظل فيها الأكلة مستبعدة من الاقتراحات بعد طبخها.';
  String get appearanceSettings =>
      isEn ? 'Appearance & Theme' : 'المظهر والألوان';
  String get themeSystem => isEn ? 'System' : 'تلقائي';
  String get themeLight => isEn ? 'Light' : 'فاتح';
  String get themeDark => isEn ? 'Dark' : 'داكن';
  String get dietaryRules => isEn ? 'Dietary Rules' : 'قواعد التنوع الغذائي';
  String get preventProteinRepeat =>
      isEn ? 'Prevent Consecutive Protein' : 'منع تكرار نوع البروتين المتتالي';
  String get preventProteinRepeatDesc => isEn
      ? 'Exclude same protein cooked today or yesterday'
      : 'استبعاد نفس البروتين المطبوخ بالأمس أو اليوم';
  String get preventCarbRepeat =>
      isEn ? 'Prevent Consecutive Carbs' : 'منع تكرار نوع النشويات المتتالي';
  String get preventCarbRepeatDesc => isEn
      ? 'Avoid repeating rice or pasta consecutively'
      : 'تجنب تكرار الأرز أو المكرونة يومين وراء بعض';
  String get dailyReminder => isEn ? 'Daily Reminder' : 'تنبيه الاقتراح اليومي';
  String get enableReminder =>
      isEn ? 'Enable Daily Reminder' : 'تفعيل التذكير اليومي';
  String get enableReminderDesc => isEn
      ? 'Notification to check today\'s meal suggestions'
      : 'إشعار تذكير لتفقد اقتراحات وجبة اليوم';
  String get reminderTime => isEn ? 'Reminder Time' : 'موعد التذكير';
  String get networkCloud => isEn ? 'Network & Cloud' : 'الشبكة والسحابة';
  String get wifiOnly =>
      isEn ? 'Cloud on Wi-Fi Only' : 'السحابة تعمل عبر Wi-Fi فقط';
  String get wifiOnlyDesc => isEn
      ? 'Download meals only when connected to Wi-Fi.'
      : 'تنزيل واستكشاف الأكلات يعمل فقط عند الاتصال بشبكة واي فاي للحفاظ على باقتك.';
  String get legalPolicies => isEn ? 'Legal Policies' : 'السياسات القانونية';
  String get privacyPolicy => isEn ? 'Privacy Policy' : 'سياسة الخصوصية';
  String get termsConditions =>
      isEn ? 'Terms & Conditions' : 'إخلاء المسؤولية والشروط';
  String get restoreDefaults =>
      isEn ? 'Restore Defaults' : 'استعادة الإعدادات الافتراضية';
  String get restoredSuccess => isEn
      ? 'Settings restored to defaults'
      : 'تم استعادة الإعدادات الافتراضية';
  String get errorOccurred => isEn ? 'An error occurred: ' : 'حدث خطأ: ';

  // Home Screen
  String get refreshSuggestions =>
      isEn ? 'Refresh Suggestions' : 'تحديث الاقتراحات';
  String get vaultEmpty => isEn ? 'Vault is empty!' : 'خزنة الأكلات فارغة!';
  String get vaultEmptyDesc => isEn
      ? 'Start by adding a meal or download suggestions.'
      : 'ابدأ بإضافة أول أكلة أو حمّل الأكلات المقترحة.';
  String get addFirstMeal => isEn ? 'Add first meal' : 'أضف أكلتك الأولى';
  String get errorPreparing =>
      isEn ? 'Error preparing suggestions' : 'حدث خطأ في تجهيز الاقتراحات';
  String get retry => isEn ? 'Retry' : 'إعادة المحاولة';
  String get todaySuggestions =>
      isEn ? 'Today\'s suggestions for you:' : 'اقتراحات النهاردة المختارة لك:';

  String greetingMorning(String name) =>
      isEn ? 'Good morning, $name ☀️' : 'صباح الفل والجمال يا $name ☀️';
  String greetingAfternoon(String name) => isEn
      ? 'What to cook today, $name? 🍲'
      : 'أكلة النهاردة.. هنطبخ إيه يا $name؟ 🍲';
  String greetingEvening(String name) =>
      isEn ? 'Good evening, $name 🌙' : 'مساء الهنا والسرور يا $name 🌙';

  String get greetingMorningNoName =>
      isEn ? 'Good morning ☀️' : 'صباح الفل والجمال ☀️';
  String get greetingAfternoonNoName =>
      isEn ? 'What to cook today? 🍲' : 'أكلة النهاردة.. هنطبخ إيه؟ 🍲';
  String get greetingEveningNoName =>
      isEn ? 'Good evening 🌙' : 'مساء الهنا والسرور 🌙';

  String get top3Balanced => isEn
      ? 'Selected best 3 balanced meals.'
      : 'اخترنا لك أفضل 3 وجبات متنوعة ومتوازنة.';
  String get spinWheel => isEn ? 'Spin the Wheel' : 'لف العجلة';
  String get varietyAlert => isEn ? 'Variety Alert' : 'تنبيه التنوع الغذائي';

  String get cookedToday => isEn ? 'Cooked Today' : 'طبختها النهاردة';
  String get leftover => isEn ? 'Leftover' : 'بواقي أكل';
  String cookedSuccess(String mealName) => isEn
      ? 'Enjoy! "$mealName" added to history.'
      : 'بالهنا والشفا! تم تسجيل "$mealName" في السجل.';
  String leftoverSuccess(String mealName) => isEn
      ? 'Logged leftover for "$mealName".'
      : 'تم تسجيل بواقي أكل "$mealName".';
  String get undo => isEn ? 'Undo' : 'تراجع';

  // Other common
  String daysText(int days) {
    if (isEn) return '$days days';
    if (days == 1) return 'يوم واحد';
    if (days == 2) return 'يومان';
    if (days <= 10) return '$days أيام';
    return '$days يوماً';
  }

  // Notifications
  String get notifications => isEn ? 'Notifications' : 'الإشعارات';
  String get sendNotification => isEn ? 'Send Notification' : 'إرسال إشعار';
  String get notificationType => isEn ? 'Notification Type' : 'نوع الإشعار';
  String get notificationTitle => isEn ? 'Title' : 'العنوان';
  String get notificationMessage => isEn ? 'Message' : 'الرسالة';
  String get titleInArabic => isEn ? 'Title in Arabic' : 'العنوان بالعربي';
  String get titleInEnglish => isEn ? 'Title in English' : 'العنوان بالإنجليزي';
  String get messageInArabic => isEn ? 'Message in Arabic' : 'الرسالة بالعربي';
  String get messageInEnglish =>
      isEn ? 'Message in English' : 'الرسالة بالإنجليزي';
  String get mealNotification => isEn ? 'Meal' : 'وجبات';
  String get reminderNotification => isEn ? 'Reminder' : 'تذكيرات';
  String get updateNotification => isEn ? 'Update' : 'تحديثات';
  String get notificationSent =>
      isEn ? 'Notification sent successfully' : 'تم إرسال الإشعار بنجاح';
  String get notificationDeleted =>
      isEn ? 'Notification deleted' : 'تم حذف الإشعار';
  String get noNotifications =>
      isEn ? 'No notifications sent yet' : 'لم يتم إرسال إشعارات بعد';
  String get sentNotifications =>
      isEn ? 'Sent Notifications' : 'الإشعارات المرسلة';
  String get confirmDeleteNotification =>
      isEn ? 'Delete this notification?' : 'حذف هذا الإشعار؟';
  String get send => isEn ? 'Send' : 'إرسال';
  String get cancel => isEn ? 'Cancel' : 'إلغاء';
  String get delete => isEn ? 'Delete' : 'حذف';
  String get sentBy => isEn ? 'Sent by' : 'أرسلها';
  String get allTypes => isEn ? 'All Types' : 'كل الأنواع';
  String get requiredField =>
      isEn ? 'This field is required' : 'هذا الحقل مطلوب';

  // AI Assistant
  String get aiAssistant =>
      isEn ? 'AI Writing Assistant' : 'مساعد الصياغة الذكي';
  String get aiAssistantSubtitle => isEn
      ? 'Generate catchy Egyptian notification copy'
      : 'توليد صياغات مصرية جذابة للإشعارات';
  String get aiPromptHint => isEn
      ? 'Type your notification idea, a meal name, or an occasion...'
      : 'اكتب فكرة الإشعار، اسم أكلة، أو مناسبة...';
  String get aiSelectModel => isEn ? 'Select model' : 'اختر موديل';
  String get aiGenerate => isEn ? 'Generate' : 'توليد';
  String get aiGenerating => isEn ? 'Generating...' : 'جارٍ التوليد...';
  String get aiGeneratedResult => isEn ? 'Generated Result' : 'نتيجة التوليد';
  String get aiApplyToForm => isEn ? 'Apply to Form' : 'تطبيق في النموذج';
  String get aiAppliedSuccess => isEn
      ? 'Notification content filled from AI assistant'
      : 'تم ملء بيانات الإشعار من المساعد الذكي';
  String get aiNoProviders => isEn
      ? 'No AI models configured. Add providers in Firebase Console.'
      : 'لا يوجد موديلات ذكاء اصطناعي. أضف مزودين في Firebase Console.';
  String get aiErrorRetry => isEn ? 'Try again' : 'جرب تاني';
}
