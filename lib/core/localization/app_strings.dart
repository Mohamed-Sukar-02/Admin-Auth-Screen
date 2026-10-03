import 'package:flutter/material.dart';

class AppStrings {
  final Locale locale;

  const AppStrings(this.locale);

  bool get isEn => locale.languageCode == 'en';

  /// Strings for the locale the surrounding [Localizations] resolved to.
  static AppStrings of(BuildContext context) =>
      AppStrings(Localizations.localeOf(context));

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

  // AI provider grouping (the admin picks a provider + model, not a key)
  String get aiAutoMode => isEn ? 'Auto' : 'تلقائي (Auto)';
  String get aiProviderGoogle => isEn ? 'Google (Gemini)' : 'جوجل (Gemini)';
  String get aiProviderGroq => isEn ? 'Groq' : 'جروك (Groq)';
  String get aiProviderOpenRouter =>
      isEn ? 'OpenRouter' : 'أوبن راوتر (OpenRouter)';

  // AI assistant panel — header strip
  String get aiAssistantHeaderTitle =>
      isEn ? 'Smart Assistant' : 'مساعدك الذكي';
  String get aiBadgeLabel => 'AI';
  String get aiStatusBusy => isEn ? 'Polishing words…' : 'بيظبط الكلام…';
  String get aiStatusReady => isEn ? 'Ready to create' : 'جاهز للإبداع';

  // AI assistant panel — generating state
  String get aiGeneratingTaste =>
      isEn ? 'Adding flavor to words…' : 'بنضيف شوية طعم للكلام…';
  String get aiStopGenerating => isEn ? 'Stop generating' : 'إيقاف التوليد';

  // AI assistant panel — welcome state
  String get aiIdeasLabel => isEn ? 'We can start with' : 'ممكن نبدأ بـ';
  String get aiWelcomeSubtitle => isEn
      ? 'Tell me what is on your mind, and I will turn it into a notification.'
      : 'قولّي في بالك إيه، وأنا أحوّله لإشعار.';
  String get aiChipKoshari => isEn ? 'Koshari for lunch' : 'كشري على الغدا';
  String get aiChipRamadan => isEn ? 'Ramadan gathering' : 'لمّة رمضان';
  String get aiChipReminder =>
      isEn ? 'Gentle lunch reminder' : 'تذكير لطيف للغدا';

  // The chips print a short name but seed the capsule with the fuller brief,
  // so the admin sees what the idea actually asks for.
  String get aiChipKoshariPrompt => isEn
      ? 'Encourage people to try the koshari recipe for lunch'
      : 'شجّع الناس يجربوا وصفة الكشري على الغدا';
  String get aiChipRamadanPrompt => isEn
      ? 'A notification about Ramadan recipes and the family iftar gathering'
      : 'إشعار عن وصفات رمضان ولمّة العيلة على الإفطار';
  String get aiChipReminderPrompt => isEn
      ? 'A gentle lunch reminder, without rushing anyone'
      : 'إشعار تذكير لطيف للغدا، من غير استعجال';

  // AI assistant panel — result card
  String get aiEgyptianSection => isEn ? 'In Egyptian' : 'بالمصري';
  String get aiEnglishSection => 'In English';
  String get aiSuggestedType => isEn ? 'Suggested Type' : 'النوع المقترح';
  String get aiApplyDraft =>
      isEn ? 'Use notification in form' : 'استخدم الإشعار في النموذج';
  String get aiAppliedDraft =>
      isEn ? 'Notification applied' : 'تم تطبيق الإشعار';
  String get aiRegenerateTooltip => isEn ? 'Another variation' : 'صياغة تانية';
  String get aiCopyTooltip => isEn ? 'Copy notification' : 'نسخ الإشعار';
  String get aiCopiedToast => isEn
      ? 'Notification copied in both languages'
      : 'تم نسخ الإشعار باللغتين';

  // AI assistant panel — prompt capsule
  String get aiPromptCapsuleHint => isEn
      ? 'What story do you want to tell today?'
      : 'إيه الحكاية اللي عايز تقولها النهاردة؟';
  String get aiSendTooltip => isEn ? 'Write the notification' : 'صياغة الإشعار';

  // AI assistant panel — footnotes
  String get aiFooterPillars => isEn
      ? 'Egyptian Arabic · Spirited English · No emoji unless requested'
      : 'عامية مصرية · إنجليزي بروحها · بدون إيموجي إلا بطلبك';

  // AI assistant panel — inline failures
  String get aiIdeaTooShort => isEn
      ? 'Tell me your idea first — a meal name or an occasion is a good start.'
      : 'قول فكرتك الأول… اسم أكلة أو مناسبة هيكون بداية حلوة.';
  String get aiApplyFailed => isEn
      ? 'Could not apply the suggestion. Try again.'
      : 'تعذّر تطبيق الاقتراح. حاول مجدداً.';
  String get aiCopyBlocked => isEn
      ? 'The browser did not allow copying. Select the text and copy it manually.'
      : 'المتصفح لم يسمح بالنسخ. تقدر تحدد النص وتنسخه يدوياً.';

  // Suggested notification kind, named exactly the way the compose form names it
  String get aiTypeMeal => isEn ? 'Meal / suggestion' : 'وجبة / اقتراح';
  String get aiTypeReminder => isEn ? 'Reminder' : 'تذكير';
  String get aiTypeUpdate => isEn ? 'Update' : 'تحديث';

  // Suggested destination & audience
  String get aiSuggestedDestination =>
      isEn ? 'Destination' : 'وجهة التوجيه';
  String get aiSuggestedAudience =>
      isEn ? 'Target audience' : 'الجمهور المستهدف';
  String get aiSuggestedSettingsTitle => isEn
      ? 'Suggested settings (applied to form):'
      : 'اقتراحات الإعدادات (تُطبَّق على النموذج):';
  String get aiDestHome => isEn ? 'Home screen' : 'الصفحة الرئيسية';
  String get aiDestMeal => isEn ? 'Specific meal' : 'وجبة محددة';
  String get aiDestVault => isEn ? 'Meals vault' : 'خزانة الأكلات';
  String get aiDestExplore => isEn ? 'Explore tab' : 'تبويب الاستكشاف';
  String get aiDestSettings => isEn ? 'Settings' : 'إعدادات التطبيق';
  String get aiDestCustom => isEn ? 'Custom link' : 'رابط مخصص';
  String get aiAudienceAll => isEn ? 'All users' : 'الجميع';
  String get aiAudienceNew => isEn ? 'New users' : 'المستخدمون الجدد';
  String get aiAudienceReturning => isEn ? 'Returning users' : 'المستخدمون العائدون';

  // AI assistant -> compose form: replacing an idea the admin already typed
  String get aiReplaceConfirmTitle =>
      isEn ? 'Use the new wording?' : 'نستخدم الصياغة الجديدة؟';
  String get aiReplaceConfirmBody => isEn
      ? 'The texts, type, destination, and target audience will be filled with the suggestions. You can still modify any field before sending.'
      : 'سيتم ملء النصوص والنوع ووجهة التوجيه والجمهور المستهدف باقتراحات المساعد. وستتمكن من تعديل أي عنصر قبل الإرسال.';
  String get aiKeepCurrent =>
      isEn ? 'Keep current content' : 'خلي المحتوى الحالي';
  String get aiUseSuggestion => isEn ? 'Use suggestion' : 'استخدم الاقتراح';

  // AI assistant -> Models settings modal
  String get aiModelsSettingsTitle =>
      isEn ? 'AI Models Configuration' : 'إعدادات أسماء الموديلات';
  String get aiModelsSettingsSubtitle => isEn
      ? 'Manage model identifiers per provider'
      : 'إدارة وتخصيص أسماء الموديلات المتاحة لكل مزود';
  String get aiModelsSettingsAddHint =>
      isEn ? 'e.g. qwen/qwen3.8-27b:free' : 'مثال: qwen/qwen3.8-27b:free';
  String get aiModelsSettingsAddBtn => isEn ? 'Add' : 'إضافة';
  String get aiModelsSettingsEmpty => isEn
      ? 'No models configured for this provider. Add one above.'
      : 'لا توجد موديلات لهذا المزود. أضف موديل من الحقل بالأعلى.';
  String get aiModelsSettingsDeleteTooltip => isEn ? 'Delete' : 'حذف';
  String get aiModelsSettingsClose => isEn ? 'Close' : 'إغلاق';
  String get aiModelsSettingsModelExists => isEn
      ? 'This model is already in the list'
      : 'هذا الموديل مضاف بالفعل في القائمة';

  // ── Vault Deduplication & Similarity Management ───────────────────────────

  // Dashboard buttons, banner & settings tile
  String get vaultDeduplicationOverviewButton =>
      isEn ? 'Review Duplicates' : 'مراجعة التكرار';
  String get vaultDeduplicationOverviewButtonScanning =>
      isEn ? 'Scanning…' : 'جارٍ الفحص…';
  String get vaultDeduplicationBannerWarning => isEn
      ? 'Similar meals detected in the vault! Click "Review Duplicates" to manage them.'
      : 'تم اكتشاف أكلات متشابهة في الخزنة! اضغط على "مراجعة التكرار" لفحصها وإدارتها.';
  String get vaultDeduplicationSettingsTileTitle =>
      isEn ? 'Clean Vault Duplicates' : 'تنظيف الخزنة من التكرار';
  String get vaultDeduplicationSettingsTileSubtitle => isEn
      ? 'Manage duplicate or similar meals with review'
      : 'إدارة وحذف النسخ المكررة أو المتشابهة مع إمكانية المراجعة';
  String get vaultDeduplicationCleanButton => isEn ? 'Clean' : 'تنظيف';
  String get vaultOperationsSection =>
      isEn ? 'Vault Operations' : 'عمليات الخزنة';

  // Modal header & subtitle
  String get vaultDeduplicationTitle =>
      isEn ? 'Vault Deduplication' : 'تنظيف الخزنة من التكرار';
  String get vaultDeduplicationSubtitle => isEn
      ? 'Review similar meals, remove duplicates, or ignore distinct dishes'
      : 'مراجعة الأكلات المتشابهة وحذف النسخ المكررة أو استبعاد الوجبات المختلفة';

  String get vaultDeduplicationTabName => isEn ? 'Name Match' : 'تشابه في الاسم';
  String get vaultDeduplicationTabId =>
      isEn ? 'Exact Name' : 'تطابق تام بالاسم';

  // Scanning & loading state
  String get vaultDeduplicationScanning => isEn
      ? 'Scanning vault meals and comparing names…'
      : 'جارٍ فحص الخزنة ومطابقة أسماء الأكلات…';
  String get vaultDeduplicationScanningSubtitle => isEn
      ? 'Calculating name similarity and filtering ignored pairs'
      : 'حساب نسبة التطابق واستبعاد الأزواج المحفوظة في قائمة التجاهل';

  // Summary banner & counts
  String vaultDeduplicationPairsFound(int count) {
    if (isEn) {
      return '$count potential duplicate ${count == 1 ? "pair" : "pairs"} found';
    }
    if (count == 0) return 'لم يتم العثور على أزواج متشابهة';
    if (count == 1) return 'تم اكتشاف زوج متشابه واحد';
    if (count == 2) return 'تم اكتشاف زوجين متشابهين';
    if (count <= 10) return 'تم اكتشاف $count أزواج متشابهة';
    return 'تم اكتشاف $count زوجاً متشابهاً';
  }

  String get vaultDeduplicationPairsFoundDesc => isEn
      ? 'Review each pair below. You can delete the duplicate or ignore the pair permanently.'
      : 'راجع كل زوج بالأسفل. يمكنك حذف النسخة المكررة أو تجاهل الزوج نهائياً.';

  // Meal comparison cards & badges
  String get vaultDeduplicationOriginalBadge =>
      isEn ? 'Original (Keep)' : 'الأصلية (ستبقى)';
  String get vaultDeduplicationDuplicateBadge =>
      isEn ? 'Duplicate (Delete)' : 'المكررة (للحذف)';
  String get vaultDeduplicationStarterMeal =>
      isEn ? 'Starter Meal' : 'أكلة أساسية';
  String vaultDeduplicationMealId(String id) =>
      isEn ? 'ID: $id' : 'المعرّف: $id';
  String get vaultDeduplicationCopyIdTooltip =>
      isEn ? 'Copy ID' : 'نسخ المعرّف';
  String get vaultDeduplicationIdCopied =>
      isEn ? 'Meal ID copied to clipboard' : 'تم نسخ معرّف الأكلة إلى الحافظة';
  String get vaultDeduplicationCopiedIdToast => vaultDeduplicationIdCopied;
  String vaultDeduplicationAddedDate(String date) =>
      isEn ? 'Added: $date' : 'أضيفت: $date';
  String vaultDeduplicationSimilarity(int percent) =>
      isEn ? '$percent% Match' : 'تطابق $percent%';
  String get vaultDeduplicationExactMatch =>
      isEn ? 'Exact match' : 'تطابق تام';
  String get vaultDeduplicationSimilarName =>
      isEn ? 'Similar name' : 'تشابه في الاسم';
  String get vaultDeduplicationExactNameDiffId =>
      isEn ? 'Exact name (different IDs)' : 'نفس الاسم بالظبط (IDs مختلفة)';

  // Card action buttons & in-flight states
  String get vaultDeduplicationDeleteAction =>
      isEn ? 'Delete Duplicate' : 'حذف المكررة';
  String get vaultDeduplicationIgnoreAction =>
      isEn ? 'Ignore' : 'تجاهل';
  String get vaultDeduplicationDeleting =>
      isEn ? 'Deleting…' : 'جارٍ الحذف…';
  String get vaultDeduplicationIgnoring =>
      isEn ? 'Ignoring…' : 'جارٍ التجاهل…';
  String get vaultDeduplicationDeleteTooltip => isEn
      ? 'Delete this duplicate meal while keeping the original'
      : 'حذف هذه النسخة المكررة مع الإبقاء على الأكلة الأصلية';
  String get vaultDeduplicationIgnoreTooltip => isEn
      ? 'Mark these meals as intentionally distinct (adds to ignored list)'
      : 'اعتبارهما أكلتين مختلفتين ولن يظهرا معاً كمقترح تكرار مستقبلاً';

  // Modal footer & global actions
  String get vaultDeduplicationClose =>
      isEn ? 'Close' : 'إغلاق';
  String get vaultDeduplicationCleanAll =>
      isEn ? 'Clean All Remaining' : 'تنظيف كل المتبقي';
  String vaultDeduplicationCleanAllWithCount(int count) => isEn
      ? 'Clean All Remaining ($count)'
      : 'تنظيف كل المتبقي ($count)';
  String get vaultDeduplicationCleaningAll =>
      isEn ? 'Cleaning remaining duplicates…' : 'جارٍ تنظيف جميع النسخ المتبقية…';

  // Confirmation dialogs
  String get vaultDeduplicationConfirmSingleDeleteTitle =>
      isEn ? 'Delete duplicate meal?' : 'حذف الوجبة المكررة؟';
  String vaultDeduplicationConfirmSingleDeleteMessage(String name) => isEn
      ? 'Are you sure you want to delete "$name"? The original meal will be kept. This cannot be undone.'
      : 'هل أنت متأكد من حذف "$name"؟ سيتم الإبقاء على الوجبة الأصلية. لا يمكن التراجع عن هذا الإجراء.';
  String get vaultDeduplicationConfirmCleanAllTitle =>
      isEn ? 'Clean all remaining duplicates?' : 'تنظيف جميع الأكلات المكررة المتبقية؟';
  String vaultDeduplicationConfirmCleanAllMessage(int count) {
    if (isEn) {
      return 'This will delete $count duplicate ${count == 1 ? "meal" : "meals"} and keep their original counterparts. Ignored pairs are not affected. This action cannot be undone.';
    }
    if (count == 1) {
      return 'سيتم حذف وجبة مكررة واحدة مع الإبقاء على نظيرتها الأصلية. لن تتأثر الأزواج المتجاهلة. لا يمكن التراجع عن هذه العملية.';
    }
    if (count == 2) {
      return 'سيتم حذف وجبتين مكررتين مع الإبقاء على نظيرتيهما الأصليتين. لن تتأثر الأزواج المتجاهلة. لا يمكن التراجع عن هذه العملية.';
    }
    if (count <= 10) {
      return 'سيتم حذف $count وجبات مكررة مع الإبقاء على نظائرها الأصلية. لن تتأثر الأزواج المتجاهلة. لا يمكن التراجع عن هذه العملية.';
    }
    return 'سيتم حذف $count وجبة مكررة مع الإبقاء على نظائرها الأصلية. لن تتأثر الأزواج المتجاهلة. لا يمكن التراجع عن هذه العملية.';
  }
  String get vaultDeduplicationConfirmCleanAllConfirm =>
      isEn ? 'Clean All Now' : 'بدء التنظيف الآن';
  String get vaultDeduplicationConfirmCleanAllCancel =>
      isEn ? 'Cancel' : 'إلغاء';
  String get vaultDeduplicationConfirmCleanAllNoteBadge =>
      isEn ? 'Permanent' : 'لا يمكن التراجع';
  String get vaultDeduplicationConfirmCleanAllNoteTitle =>
      isEn ? 'Bulk Deletion' : 'عملية حذف جماعية';

  // Empty & error states
  String get vaultDeduplicationEmptyTitle =>
      isEn ? 'Vault is completely clean!' : 'الخزنة نظيفة تماماً!';
  String get vaultDeduplicationEmptySubtitle => isEn
      ? 'No duplicate or similar meals found in the vault.'
      : 'لا توجد أي أكلات مكررة أو متشابهة في الخزنة حالياً.';
  String get vaultDeduplicationErrorTitle =>
      isEn ? 'Error scanning duplicates' : 'حدث خطأ أثناء فحص التكرار';
  String get vaultDeduplicationRetry =>
      isEn ? 'Try Again' : 'إعادة المحاولة';

  // Feedback toasts & snackbars
  String vaultDeduplicationDeletedSuccess(String name) => isEn
      ? 'Deleted duplicate "$name"'
      : 'تم حذف النسخة المكررة "$name" بنجاح';
  String vaultDeduplicationIgnoredSuccess(String nameA, String nameB) => isEn
      ? 'Pair "$nameA" & "$nameB" marked as ignored'
      : 'تمت إضافة الزوج "$nameA" و "$nameB" إلى قائمة التجاهل';
  String vaultDeduplicationAllCleanedSuccess(int count) {
    if (isEn) {
      return 'Successfully deleted $count duplicate ${count == 1 ? "meal" : "meals"}';
    }
    if (count == 1) return 'تم بنجاح حذف وجبة مكررة واحدة';
    if (count == 2) return 'تم بنجاح حذف وجبتين مكررتين';
    if (count <= 10) return 'تم بنجاح تنظيف وحذف $count وجبات مكررة';
    return 'تم بنجاح تنظيف وحذف $count وجبة مكررة';
  }
  String get vaultDeduplicationCleanAlreadyClean =>
      isEn ? 'The vault is already clean' : 'الخزنة نظيفة بالفعل';
  String vaultDeduplicationErrorToast(String error) => isEn
      ? 'Failed to process duplicate: $error'
      : 'فشلت معالجة التكرار: $error';
  String vaultDeduplicationErrorCleanAllToast(String error) => isEn
      ? 'Failed to clean duplicates: $error'
      : 'فشل تنظيف الأكلات المكررة: $error';
}


