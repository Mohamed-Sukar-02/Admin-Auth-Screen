import 'dart:math' as math;

import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/database/app_database.dart';
import '../../settings/providers/settings_providers.dart';
import '../data/admin_auth_service.dart';
import '../data/admin_security_service.dart';
import '../data/admin_sidebar_prefs.dart';
import '../data/admin_system_config_repository.dart';
import '../data/models/cloud_meal.dart';
import '../data/vault_admin_repository.dart';
import 'notification_management_screen.dart';
import 'theme/admin_palette.dart';
import 'widgets/add_meal_dialog.dart';
import 'widgets/admin_dialog.dart';
import 'widgets/admin_toast.dart';
import 'widgets/deduplication_dialog.dart';
import '../../../core/localization/app_strings.dart';
import '../domain/similarity_engine.dart';


/// -------------------------------------------------------------------------
/// Helpers
/// -------------------------------------------------------------------------
String _themeModeLabel(AppThemeModePreference mode) => switch (mode) {
  AppThemeModePreference.light => 'الوضع النهاري',
  AppThemeModePreference.dark => 'الوضع الداكن',
  AppThemeModePreference.system => 'مظهر النظام',
};

Color _categoryColor(String category, AdminPalette p) {
  switch (category) {
    case 'starter':
      return p.oliveSolid;
    case 'tabeekh':
      return p.claySolid;
    case 'casserole':
      return p.honeySolid;
    case 'dry_sandwich':
      return p.plumSolid;
    case 'popular':
      return p.chiliSolid;
    case 'seafood':
      return p.nileSolid;
    case 'soup_stew':
      return p.clayDeep;
    case 'vegetarian':
      return p.oliveSolid;
    default:
      return p.inkFaint;
  }
}

String _translateCategory(String cat) {
  switch (cat) {
    case 'tabeekh':
      return 'طبيخ';
    case 'casserole':
      return 'صواني فرن';
    case 'dry_sandwich':
      return 'نواشف';
    case 'popular':
      return 'شعبي';
    case 'seafood':
      return 'بحريات';
    case 'soup_stew':
      return 'شوربات';
    case 'vegetarian':
      return 'نباتي';
    default:
      return cat;
  }
}

String _translateProtein(String protein) {
  switch (protein) {
    case 'chicken':
      return 'فراخ';
    case 'beef':
      return 'لحمة';
    case 'fish':
      return 'سمك';
    case 'meatless':
      return 'نباتي';
    default:
      return 'أخرى';
  }
}

String _translateCarbs(String carbs) {
  switch (carbs) {
    case 'rice':
      return 'أرز';
    case 'pasta':
      return 'مكرونة';
    case 'bread':
      return 'عيش';
    default:
      return 'بدون';
  }
}

/// Sidebar order, and therefore the page index: workspace group first
/// (الرئيسية، الاقتراحات), then system group (الإشعارات، الإعدادات).
const List<({String title, String subtitle})> _pageMeta = [
  (title: 'نظرة عامة', subtitle: 'الخزنة العامة وأداء المحتوى في لمحة'),
  (title: 'المقترحات', subtitle: 'مراجعة واعتماد أكلات المستخدمين'),
  (
    title: 'إدارة الإشعارات',
    subtitle: 'إرسال وتتبع إشعارات التطبيق لجميع المستخدمين',
  ),
  (title: 'الإعدادات', subtitle: 'النظام والصلاحيات والنسخ الاحتياطي'),
];

/// -------------------------------------------------------------------------
/// Admin dashboard
/// -------------------------------------------------------------------------
const double _sidebarDefaultWidth = 268;
const double _sidebarMinWidth = 210;
const double _sidebarMaxWidth = 430;
const double _sidebarRailWidth = 78;
const Duration _sidebarSlide = Duration(milliseconds: 240);

class AdminDashboardScreen extends ConsumerStatefulWidget {
  const AdminDashboardScreen({super.key});

  @override
  ConsumerState<AdminDashboardScreen> createState() =>
      _AdminDashboardScreenState();
}

class _AdminDashboardScreenState extends ConsumerState<AdminDashboardScreen> {
  int _navIndex =
      0; // 0 = الرئيسية, 1 = الاقتراحات, 2 = الإشعارات, 3 = الإعدادات
  String _searchQuery = '';
  String _selectedCategory = 'all';
  bool _isProcessingBackup = false;


  late double _sidebarWidth;
  late bool _sidebarCollapsed;
  bool _isResizingSidebar = false;

  final _searchController = TextEditingController();

  final _categories = const [
    {'key': 'all', 'label': 'الكل'},
    {'key': 'starter', 'label': 'أساسية'},
    {'key': 'tabeekh', 'label': 'طبيخ'},
    {'key': 'casserole', 'label': 'صواني'},
    {'key': 'dry_sandwich', 'label': 'نواشف'},
    {'key': 'popular', 'label': 'شعبي'},
    {'key': 'seafood', 'label': 'بحريات'},
    {'key': 'soup_stew', 'label': 'شوربات'},
    {'key': 'vegetarian', 'label': 'نباتي'},
  ];

  @override
  void initState() {
    super.initState();
    _sidebarWidth = readSidebarWidth() ?? _sidebarDefaultWidth;
    _sidebarCollapsed = readSidebarCollapsed();
  }

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _toggleSidebarCollapsed() {
    setState(() => _sidebarCollapsed = !_sidebarCollapsed);
    writeSidebarCollapsed(_sidebarCollapsed);
  }

  void _onSidebarResizeUpdate(double outwardDelta) {
    setState(() {
      _sidebarWidth = (_sidebarWidth + outwardDelta)
          .clamp(_sidebarMinWidth, _sidebarMaxWidth)
          .toDouble();
      _isResizingSidebar = true;
    });
  }

  void _onSidebarResizeEnd() {
    setState(() => _isResizingSidebar = false);
    writeSidebarWidth(_sidebarWidth);
  }

  void _onSearchChanged(String value) {
    setState(() {
      _searchQuery = value;
      if (value.trim().isNotEmpty && _navIndex != 0) _navIndex = 0;
    });
  }

  void _openAddMealDialog([CloudMeal? meal]) {
    showAdminDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => AddMealDialog(initialMeal: meal),
    );
  }

  void _editStaging(CloudMeal stagingMeal) {
    showAdminDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) =>
          AddMealDialog(initialMeal: stagingMeal, isStaging: true),
    );
  }

  Future<void> _confirmDelete(CloudMeal meal, AdminPalette p) async {
    final confirmed = await showAdminConfirmDialog(
      context: context,
      icon: AdminIcons.delete,
      tone: AdminDialogTone.danger,
      title: 'حذف الأكلة',
      message:
          'سيتم حذف الأكلة نهائياً من الخزنة العامة. يمكنك التراجع فوراً من خلال الشريط السفلي بعد الحذف.',
      note: AdminDialogNote(
        tone: AdminDialogTone.danger,
        icon: AdminIcons.meal,
        leading: AdminDialogThumb(imageUrl: meal.imageUrl),
        title: meal.name,
        subtitle:
            '${_translateCategory(meal.category)} • ${_translateProtein(meal.proteinType)} • ${meal.prepTimeMinutes} دقيقة',
      ),
      confirmLabel: 'حذف نهائي',
      confirmIcon: AdminIcons.delete,
    );

    if (!confirmed) return;

    final progress = AdminToast.loading(
      message: 'جارٍ حذف "${meal.name}"',
      subtitle: 'يُحدَّث الخزنة العامة الآن',
    );
    try {
      await ref.read(vaultAdminRepositoryProvider).deleteVaultMeal(meal.id);
      progress.resolve(
        message: 'تم حذف "${meal.name}"',
        subtitle: 'اضغط تراجع لاستعادة الأكلة',
        kind: AdminToastKind.warning,
        onUndo: () async {
          await FirebaseFirestore.instance
              .collection('vault_meals')
              .doc(meal.id)
              .set(meal.toMap());
        },
      );
    } catch (e) {
      progress.resolve(
        message: 'تعذر حذف الأكلة',
        subtitle: e.toString(),
        kind: AdminToastKind.error,
      );
    }
  }

  void _approveStaging(CloudMeal stagingMeal) async {
    final repo = ref.read(vaultAdminRepositoryProvider);
    final exists = await repo.mealExists(stagingMeal.name);

    if (exists && mounted) {
      final force = await showAdminConfirmDialog(
        context: context,
        icon: AdminIcons.warning,
        tone: AdminDialogTone.warn,
        title: 'تحذير: أكلة مكررة',
        message:
            'توجد أكلة بنفس الاسم في الخزنة بالفعل. يمكنك اعتمادها كنسخة جديدة، أو إلغاء العملية ومراجعة المقترح.',
        note: AdminDialogNote(
          tone: AdminDialogTone.warn,
          icon: AdminIcons.meal,
          leading: AdminDialogThumb(imageUrl: stagingMeal.imageUrl),
          title: stagingMeal.name,
          subtitle: 'موجودة مسبقاً في الخزنة العامة',
        ),
        confirmLabel: 'اعتماد كنسخة جديدة',
        confirmIcon: AdminIcons.add,
      );

      if (!force) return;
    }

    final progress = AdminToast.loading(
      message: 'جارٍ اعتماد "${stagingMeal.name}"',
      subtitle: 'يُنقل المقترح إلى الخزنة العامة',
    );
    try {
      await repo.approveStagingMeal(stagingMeal);
      progress.resolve(
        message: 'تم اعتماد "${stagingMeal.name}"',
        subtitle: 'أُضيفت الأكلة إلى الخزنة بنجاح',
        kind: AdminToastKind.success,
      );
    } catch (e) {
      progress.resolve(
        message: 'تعذر اعتماد المقترح',
        subtitle: e.toString(),
        kind: AdminToastKind.error,
      );
    }
  }

  void _rejectStaging(CloudMeal stagingMeal) async {
    final progress = AdminToast.loading(
      message: 'جارٍ رفض "${stagingMeal.name}"',
    );
    try {
      await ref
          .read(vaultAdminRepositoryProvider)
          .rejectStagingMeal(stagingMeal.id);
      progress.resolve(
        message: 'تم رفض "${stagingMeal.name}"',
        subtitle: 'اضغط تراجع لاستعادة المقترح',
        kind: AdminToastKind.warning,
        onUndo: () async {
          await FirebaseFirestore.instance
              .collection('staging_meals')
              .doc(stagingMeal.id)
              .set(stagingMeal.toMap());
        },
      );
    } catch (e) {
      progress.resolve(
        message: 'تعذر رفض المقترح',
        subtitle: e.toString(),
        kind: AdminToastKind.error,
      );
    }
  }

  void _showMealDetails(CloudMeal meal) {
    final p = AdminPalette.of(context);
    final tint = p.proteinTint(meal.proteinType);
    final catColor = _categoryColor(meal.category, p);

    showAdminDialog(
      context: context,
      builder: (ctx) => AdminDialogShell(
        icon: AdminIcons.meal,
        tone: AdminDialogTone.brand,
        title: meal.name,
        subtitle:
            '${_translateCategory(meal.category)} • ${_translateProtein(meal.proteinType)}',
        hero: AdminDialogHero(imageUrl: meal.imageUrl),
        maxWidth: 470,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                _Pill(
                  label: _translateProtein(meal.proteinType),
                  bg: tint.bg,
                  fg: tint.fg,
                  icon: AdminIcons.protein,
                ),
                _Pill(
                  label: _translateCategory(meal.category),
                  bg: catColor.withValues(alpha: 0.14),
                  fg: catColor,
                  icon: AdminIcons.category,
                ),
                if (meal.isStarterMeal)
                  _Pill(
                    label: 'Starter Pack',
                    bg: p.honeySoft,
                    fg: p.honeyInk,
                    icon: AdminIcons.starter,
                  ),
              ],
            ),
            const SizedBox(height: 16),
            AdminSpecGrid(
              tiles: [
                AdminSpecTile(
                  icon: AdminIcons.carbs,
                  label: 'النشويات',
                  value: _translateCarbs(meal.carbsType),
                ),
                AdminSpecTile(
                  icon: AdminIcons.time,
                  label: 'وقت التحضير',
                  value: '${meal.prepTimeMinutes} دقيقة',
                ),
                if (meal.isFridaySpecial)
                  const AdminSpecTile(
                    icon: AdminIcons.friday,
                    label: 'المناسبة',
                    value: 'أكلة جمعة / عزومات',
                  ),
                if (meal.isStarterMeal)
                  const AdminSpecTile(
                    icon: AdminIcons.starter,
                    label: 'التوزيع',
                    value: 'تُنزّل تلقائياً للمستخدمين الجدد',
                  ),
                AdminSpecTile(
                  icon: meal.proposedBy != null
                      ? AdminIcons.source
                      : AdminIcons.basicInfo,
                  label: meal.proposedBy != null ? 'مقترح من' : 'المصدر',
                  value: meal.proposedBy ?? 'إضافة المشرف',
                ),
              ],
            ),
            if (meal.notes != null && meal.notes!.isNotEmpty) ...[
              const SizedBox(height: 14),
              AdminDialogPanel(icon: AdminIcons.notes, text: meal.notes!),
            ],
          ],
        ),
      ),
    );
  }

  Future<void> _handleDeduplication([AdminPalette? p]) async {
    await showAdminDialog(
      context: context,
      barrierDismissible: true,
      builder: (ctx) => const DeduplicationDialog(),
    );
  }


  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    final user = ref.watch(authStateProvider).value;
    final userRoleAsync = ref.watch(adminRoleProvider(user?.email));
    final isSuperAdmin = userRoleAsync.value == 'super_admin';
    final isViewingAdmin = userRoleAsync.value == 'viewing_admin';
    final vaultMealsAsync = ref.watch(vaultMealsStreamProvider);
    final stagingMealsAsync = ref.watch(stagingMealsStreamProvider);
    final pendingCount = stagingMealsAsync.value?.length ?? 0;

    return Title(
      title: 'Vault - أكلة النهاردة',
      color: Theme.of(context).colorScheme.primary,
      child: LayoutBuilder(
        builder: (context, constraints) {
          final isMobile = constraints.maxWidth < 900;

          final content = Directionality(
            textDirection: TextDirection.rtl,
            child: Column(
              children: [
                _TopBar(
                  userEmail: user?.email,
                  pageIndex: _navIndex,
                  searchController: _searchController,
                  onSearchChanged: _onSearchChanged,
                  onAddMeal: isViewingAdmin
                      ? null
                      : () => _openAddMealDialog(null),
                  showAddButton: _navIndex == 0,
                  showSearch: _navIndex == 0,
                ),
                Expanded(
                  child: IndexedStack(
                    index: _navIndex,
                    children: [
                      _buildOverviewPage(
                        vaultMealsAsync,
                        pendingCount,
                        p,
                        isViewingAdmin,
                      ),
                      _buildSuggestionsPage(
                        stagingMealsAsync,
                        p,
                        isViewingAdmin,
                      ),
                      const NotificationManagementScreen(),
                      _buildSettingsPage(user, p, isSuperAdmin),
                    ],
                  ),
                ),
              ],
            ),
          );

          // The sidebar is laid out on the desktop branch only: measuring it
          // for a phone clamps against `maxWidth - 560`, a negative upper
          // limit, which throws before any page paints.
          final sidebarWidth = isMobile || _sidebarCollapsed
              ? _sidebarRailWidth
              : _sidebarWidth
                    .clamp(
                      _sidebarMinWidth,
                      math.min(_sidebarMaxWidth, constraints.maxWidth - 560),
                    )
                    .toDouble();

          return Scaffold(
            backgroundColor: p.canvas,
            body: isMobile
                ? content
                : Directionality(
                    textDirection: TextDirection.rtl,
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        _Sidebar(
                          width: sidebarWidth,
                          collapsed: _sidebarCollapsed,
                          animate: !_isResizingSidebar,
                          selectedIndex: _navIndex,
                          pendingCount: pendingCount,
                          onSelect: (idx) => setState(() => _navIndex = idx),
                          onToggleCollapsed: _toggleSidebarCollapsed,
                        ),
                        if (!_sidebarCollapsed)
                          _SidebarResizeHandle(
                            isDragging: _isResizingSidebar,
                            onUpdate: _onSidebarResizeUpdate,
                            onEnd: _onSidebarResizeEnd,
                          ),
                        Expanded(child: content),
                      ],
                    ),
                  ),
            bottomNavigationBar: isMobile
                ? Directionality(
                    textDirection: TextDirection.rtl,
                    child: _MobileNav(
                      selectedIndex: _navIndex,
                      pendingCount: pendingCount,
                      onSelect: (idx) => setState(() => _navIndex = idx),
                    ),
                  )
                : null,
          );
        },
      ),
    );
  }

  // ---------------------------------------------------------------------
  // صفحة الرئيسية
  // ---------------------------------------------------------------------
  Widget _buildOverviewPage(
    AsyncValue<List<CloudMeal>> vaultMealsAsync,
    int pendingCount,
    AdminPalette p,
    bool isViewingAdmin,
  ) {
    final vaultList = vaultMealsAsync.value ?? [];
    final isMobile = MediaQuery.sizeOf(context).width < 900;
    final strings = AppStrings.of(context);

    final hasDuplicates = () {
      final names = <String>{};
      for (final m in vaultList) {
        final n = SimilarityEngine.normalizeArabic(m.name);
        if (n.isNotEmpty && !names.add(n)) return true;
      }
      return false;
    }();

    final cards = <Widget>[
      _StatCard(
        icon: AdminIcons.meal,
        bg: p.nileSoft,
        accent: p.nileInk,
        label: 'إجمالي الأكلات',
        value: '${vaultList.length}',
        trend: vaultList.isNotEmpty ? 'في الخزنة العامة' : null,
      ),
      _StatCard(
        icon: AdminIcons.suggestions,
        bg: p.honeySoft,
        accent: p.honeyInk,
        label: 'مقترحات قيد المراجعة',
        value: '$pendingCount',
        trend: pendingCount > 0 ? 'محتاجة مراجعة' : 'مفيش مقترحات معلقة',
        onTap: () => setState(() => _navIndex = 1),
      ),
      _CategoryStatsCard(meals: vaultList),
      _LeaderboardCard(meals: vaultList),
    ];

    return SingleChildScrollView(
      padding: EdgeInsets.all(isMobile ? 16 : 26),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          LayoutBuilder(
            builder: (context, constraints) {
              final w = constraints.maxWidth;
              if (w >= 1040) {
                return IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      for (var i = 0; i < cards.length; i++) ...[
                        if (i > 0) const SizedBox(width: 18),
                        Expanded(child: cards[i]),
                      ],
                    ],
                  ),
                );
              }
              if (w >= 540) {
                return Column(
                  children: [
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: cards[0]),
                          const SizedBox(width: 18),
                          Expanded(child: cards[1]),
                        ],
                      ),
                    ),
                    const SizedBox(height: 18),
                    IntrinsicHeight(
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          Expanded(child: cards[2]),
                          const SizedBox(width: 18),
                          Expanded(child: cards[3]),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  for (final c in cards) ...[c, const SizedBox(height: 14)],
                ],
              );
            },
          ),
          const SizedBox(height: 30),
          AdminSectionHeader(
            title: 'الخزنة العامة',
            subtitle: 'إدارة الأكلات المعتمدة في الخزنة العامة',
            trailing: hasDuplicates
                ? FilledButton.icon(
                    onPressed: () => _handleDeduplication(p),
                    icon: const Icon(AdminIcons.cleanup, size: 16),
                    label: Text(
                      strings.vaultDeduplicationOverviewButton,
                      style: adminText(size: 13, weight: FontWeight.bold),
                    ),
                    style: FilledButton.styleFrom(
                      backgroundColor: p.honeySolid,
                      foregroundColor: p.onSolid(p.honeySolid),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 16,
                        vertical: 14,
                      ),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(AdminRadii.md),
                      ),
                    ),
                  )
                : null,
          ),
          if (hasDuplicates) ...[
            const SizedBox(height: 14),
            _NoticeBanner(
              icon: AdminIcons.warning,
              message: strings.vaultDeduplicationBannerWarning,
              bg: p.honeySoft,
              fg: p.honeyInk,
            ),
          ],

          const SizedBox(height: 18),
          Container(
            padding: const EdgeInsets.all(16),
            decoration: p.panel(),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(AdminIcons.settings, size: 18, color: p.inkMuted),
                    const SizedBox(width: 8),
                    Text(
                      'تصفية حسب التصنيف',
                      style: adminText(
                        size: 13,
                        weight: FontWeight.w600,
                        color: p.inkMuted,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: _categories.map((c) {
                      final key = c['key']!;
                      final isSelected = _selectedCategory == key;
                      final dot = key == 'all'
                          ? p.inkMuted
                          : _categoryColor(key, p);
                      return Padding(
                        padding: const EdgeInsets.only(left: 8),
                        child: _FilterChip(
                          label: c['label']!,
                          dotColor: dot,
                          selected: isSelected,
                          onTap: () => setState(() => _selectedCategory = key),
                        ),
                      );
                    }).toList(),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 22),
          vaultMealsAsync.when(
            loading: () => const Padding(
              padding: EdgeInsets.symmetric(vertical: 60),
              child: Center(child: CircularProgressIndicator()),
            ),
            error: (err, stack) => Padding(
              padding: const EdgeInsets.symmetric(vertical: 40),
              child: Center(
                child: Text(
                  'تعذر جلب الأكلات: $err',
                  style: adminText(color: p.inkMuted),
                ),
              ),
            ),
            data: (meals) {
              final query = _searchQuery.trim().toLowerCase();
              final filtered = meals.where((m) {
                final q = query;
                final matchesSearch = q.isEmpty ||
                    m.name.toLowerCase().contains(q) ||
                    _translateCategory(m.category).contains(q) ||
                    _translateProtein(m.proteinType).contains(q) ||
                    _translateCarbs(m.carbsType).contains(q) ||
                    (m.isStarterMeal && 'الأساسية اساسي اساسية اساسيه الأساسيه starter'.contains(q)) ||
                    (m.isFridaySpecial && 'عزومات جمعة عزومة الجمعة friday'.contains(q));
                final matchesCat = _selectedCategory == 'all' ||
                    (_selectedCategory == 'starter'
                        ? m.isStarterMeal
                        : m.category == _selectedCategory);
                return matchesSearch && matchesCat;
              }).toList();

              if (filtered.isEmpty) {
                return _EmptyState(
                  icon: meals.isEmpty ? AdminIcons.meal : AdminIcons.searchOff,
                  title: meals.isEmpty
                      ? 'لا توجد أكلات في الخزنة حتى الآن'
                      : 'لا توجد نتائج مطابقة',
                  message: meals.isEmpty
                      ? 'ابدأ بإضافة أول أكلة للخزنة العامة من زر "إضافة أكلة جديدة".'
                      : 'جرّب تغيير كلمة البحث أو اختيار تصنيف مختلف.',
                  fg: p.inkFaint,
                );
              }

              return Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Row(
                    children: [
                      Text(
                        '${filtered.length}',
                        style: adminText(
                          size: 14,
                          weight: FontWeight.bold,
                          color: p.clay,
                        ),
                      ),
                      const SizedBox(width: 6),
                      Text(
                        'نتيجة معروضة',
                        style: adminText(size: 13, color: p.inkMuted),
                      ),
                      const Spacer(),
                      if (_searchQuery.trim().isNotEmpty)
                        TextButton.icon(
                          onPressed: () {
                            _searchController.clear();
                            _onSearchChanged('');
                          },
                          icon: Icon(
                            AdminIcons.close,
                            size: 16,
                            color: p.inkMuted,
                          ),
                          label: Text(
                            'مسح البحث',
                            style: adminText(size: 12, color: p.inkMuted),
                          ),
                        ),
                    ],
                  ),
                  const SizedBox(height: 12),
                  GridView.builder(
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    gridDelegate:
                        const SliverGridDelegateWithMaxCrossAxisExtent(
                          maxCrossAxisExtent: 330,
                          crossAxisSpacing: 18,
                          mainAxisSpacing: 18,
                          mainAxisExtent: 322,
                        ),
                    itemCount: filtered.length,
                    itemBuilder: (context, index) {
                      final meal = filtered[index];
                      return _VaultMealCard(
                        meal: meal,
                        onEdit: isViewingAdmin
                            ? null
                            : () => _openAddMealDialog(meal),
                        onDelete: isViewingAdmin
                            ? null
                            : () => _confirmDelete(meal, p),
                        onDetails: () => _showMealDetails(meal),
                      );
                    },
                  ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }

  // ---------------------------------------------------------------------
  // صفحة الاقتراحات
  // ---------------------------------------------------------------------
  Widget _buildSuggestionsPage(
    AsyncValue<List<CloudMeal>> stagingAsync,
    AdminPalette p,
    bool isViewingAdmin,
  ) {
    final isMobile = MediaQuery.sizeOf(context).width < 900;

    return stagingAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (err, stack) => Center(
        child: Text(
          'خطأ في جلب المقترحات: $err',
          style: adminText(color: p.inkMuted),
        ),
      ),
      data: (stagingMeals) {
        return Padding(
          padding: EdgeInsets.all(isMobile ? 16 : 26),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Container(
                padding: const EdgeInsets.all(20),
                decoration: p.panel(),
                child: Row(
                  children: [
                    _IconTile(
                      icon: AdminIcons.suggestions,
                      fg: p.honeyInk,
                      bg: p.honeySoft,
                    ),
                    const SizedBox(width: 14),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'المقترحات المعلقة',
                            style: adminText(
                              size: 16,
                              weight: FontWeight.bold,
                              color: p.ink,
                            ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            'راجع واعتمد المقترحات الجديدة من المستخدمين',
                            style: adminText(size: 12, color: p.inkMuted),
                          ),
                        ],
                      ),
                    ),
                    if (stagingMeals.isNotEmpty)
                      _Pill(
                        label: '${stagingMeals.length}',
                        bg: p.honeySolid,
                        fg: p.onSolid(p.honeySolid),
                      ),
                  ],
                ),
              ),
              const SizedBox(height: 18),
              Expanded(
                child: stagingMeals.isEmpty
                    ? _EmptyState(
                        icon: AdminIcons.success,
                        title: 'لا توجد مقترحات معلقة حالياً!',
                        message:
                            'كل الاقتراحات تمت مراجعتها. هتلاقي الجديد هنا فور وصوله.',
                        fg: p.oliveSolid,
                      )
                    : ListView.separated(
                        padding: const EdgeInsets.only(bottom: 12),
                        itemCount: stagingMeals.length,
                        separatorBuilder: (_, _) => const SizedBox(height: 12),
                        itemBuilder: (context, index) {
                          final meal = stagingMeals[index];
                          return _SuggestionRow(
                            meal: meal,
                            onApprove: isViewingAdmin
                                ? null
                                : () => _approveStaging(meal),
                            onReject: isViewingAdmin
                                ? null
                                : () => _rejectStaging(meal),
                            onEdit: isViewingAdmin
                                ? null
                                : () => _editStaging(meal),
                            onDetails: () => _showMealDetails(meal),
                          );
                        },
                      ),
              ),
            ],
          ),
        );
      },
    );
  }

  // ---------------------------------------------------------------------
  // صفحة الإعدادات
  // ---------------------------------------------------------------------
  Widget _buildSettingsPage(dynamic user, AdminPalette p, bool isSuperAdmin) {
    final strings = AppStrings.of(context);
    return SingleChildScrollView(

      padding: const EdgeInsets.fromLTRB(26, 20, 26, 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 640),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // The shell's top bar already prints this page's title and
            // subtitle, so the page opens straight on its first section.
            // ── Profile section ─────────────────────────────────────────────
            _SettingsSectionLabel(label: 'الحساب', palette: p),
            const SizedBox(height: 10),
            Container(
              decoration: p.panel(shadow: true),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  // gradient header
                  Container(
                    height: 72,
                    decoration: BoxDecoration(gradient: p.brandGradient),
                  ),
                  Padding(
                    padding: const EdgeInsets.fromLTRB(20, 0, 20, 20),
                    child: Column(
                      children: [
                        Row(
                          crossAxisAlignment: CrossAxisAlignment.end,
                          children: [
                            Transform.translate(
                              offset: const Offset(0, -28),
                              child: Container(
                                width: 56,
                                height: 56,
                                decoration: BoxDecoration(
                                  gradient: p.brandGradient,
                                  borderRadius: BorderRadius.circular(
                                    AdminRadii.md,
                                  ),
                                  border: Border.all(
                                    color: p.surface,
                                    width: 3,
                                  ),
                                ),
                                child: Icon(
                                  AdminIcons.person,
                                  color: p.onSolid(
                                    p.brandGradient.colors.first,
                                  ),
                                  size: 28,
                                ),
                              ),
                            ),
                            const SizedBox(width: 12),
                            Expanded(
                              child: Padding(
                                padding: const EdgeInsets.only(bottom: 4),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(
                                      user?.email ?? 'المشرف',
                                      style: adminText(
                                        size: 14,
                                        weight: FontWeight.bold,
                                        color: p.ink,
                                      ),
                                      overflow: TextOverflow.ellipsis,
                                    ),
                                    const SizedBox(height: 5),
                                    _Pill(
                                      label: isSuperAdmin
                                          ? 'Super Admin'
                                          : 'Admin',
                                      bg: isSuperAdmin
                                          ? p.claySoft
                                          : p.surfaceSunken,
                                      fg: isSuperAdmin
                                          ? p.onClaySoft
                                          : p.inkMuted,
                                      icon: isSuperAdmin
                                          ? AdminIcons.verified
                                          : AdminIcons.person,
                                    ),
                                  ],
                                ),
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        SizedBox(
                          width: double.infinity,
                          child: OutlinedButton.icon(
                            onPressed: () =>
                                ref.read(adminAuthProvider).signOut(),
                            icon: Icon(
                              AdminIcons.logout,
                              size: 17,
                              color: p.chiliInk,
                            ),
                            label: Text(
                              'تسجيل الخروج',
                              style: adminText(size: 13, color: p.chiliInk),
                            ),
                            style: OutlinedButton.styleFrom(
                              foregroundColor: p.chiliInk,
                              side: BorderSide(
                                color: p.chiliSolid.withValues(alpha: 0.4),
                              ),
                              padding: const EdgeInsets.symmetric(vertical: 13),
                              shape: RoundedRectangleBorder(
                                borderRadius: BorderRadius.circular(
                                  AdminRadii.md,
                                ),
                              ),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Appearance section ──────────────────────────────────────────
            _SettingsSectionLabel(label: 'المظهر', palette: p),
            const SizedBox(height: 10),
            _buildAppearanceCard(p),

            const SizedBox(height: 28),

            // ── System control section ─────────────────────────────────────
            _SettingsSectionLabel(label: 'التحكم بالنظام', palette: p),
            const SizedBox(height: 10),
            Container(
              decoration: p.panel(),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _buildSettingsTile(
                    p: p,
                    icon: AdminIcons.settings,
                    iconColor: p.claySolid,
                    iconBg: p.claySoft,
                    title: 'إعدادات النظام',
                    subtitle: 'أيام التبريد، تحديثات التطبيق، الإعلانات',
                    locked: !isSuperAdmin,
                    trailing: _SettingsChevronButton(
                      label: 'إدارة',
                      color: p.claySolid,
                      bg: p.claySoft,
                      enabled: isSuperAdmin,
                      onTap: () => _showSystemConfigDialog(p),
                    ),
                  ),
                  _SettingsDivider(p: p),
                  _buildSettingsTile(
                    p: p,
                    icon: AdminIcons.admins,
                    iconColor: p.plumSolid,
                    iconBg: p.plumSoft,
                    title: 'إدارة المشرفين',
                    subtitle: 'إضافة أو إزالة المشرفين وتحديد صلاحياتهم',
                    locked: !isSuperAdmin,
                    trailing: _SettingsChevronButton(
                      label: 'إدارة',
                      color: p.plumSolid,
                      bg: p.plumSoft,
                      enabled: isSuperAdmin,
                      onTap: () => _showAdminManagementDialog(p, user?.email),
                    ),
                  ),
                ],
              ),
            ),

            const SizedBox(height: 28),

            // ── Vault operations section ───────────────────────────────────
            _SettingsSectionLabel(
              label: strings.vaultOperationsSection,
              palette: p,
            ),
            const SizedBox(height: 10),
            Container(
              decoration: p.panel(),
              clipBehavior: Clip.antiAlias,
              child: Column(
                children: [
                  _buildSettingsTile(
                    p: p,
                    icon: AdminIcons.cleanup,
                    iconColor: p.honeyInk,
                    iconBg: p.honeySoft,
                    title: strings.vaultDeduplicationSettingsTileTitle,
                    subtitle: strings.vaultDeduplicationSettingsTileSubtitle,
                    locked: !isSuperAdmin,
                    trailing: _SettingsChevronButton(
                      label: strings.vaultDeduplicationCleanButton,
                      color: p.honeyInk,
                      bg: p.honeySoft,
                      enabled: isSuperAdmin,
                      onTap: () => _handleDeduplication(p),
                    ),
                  ),
                  _SettingsDivider(p: p),

                  // Backup & Restore combined tile
                  Padding(
                    padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
                    child: Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        _IconTile(
                          icon: AdminIcons.backup,
                          fg: isSuperAdmin ? p.nileSolid : p.inkFaint,
                          bg: isSuperAdmin ? p.nileSoft : p.surfaceSunken,
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    'النسخ الاحتياطي والاستعادة',
                                    style: adminText(
                                      size: 14,
                                      weight: FontWeight.bold,
                                      color: isSuperAdmin ? p.ink : p.inkMuted,
                                    ),
                                  ),
                                  if (!isSuperAdmin) ...[
                                    const SizedBox(width: 8),
                                    _Pill(
                                      label: 'Super Admin فقط',
                                      bg: p.surfaceSunken,
                                      fg: p.inkFaint,
                                      icon: AdminIcons.lock,
                                    ),
                                  ],
                                ],
                              ),
                              const SizedBox(height: 3),
                              Text(
                                'حفظ أو استعادة بيانات الخزنة الكاملة',
                                style: adminText(size: 12, color: p.inkMuted),
                              ),
                              const SizedBox(height: 12),
                              Opacity(
                                opacity: isSuperAdmin ? 1.0 : 0.4,
                                child: Row(
                                  children: [
                                    Expanded(
                                      child: OutlinedButton.icon(
                                        onPressed:
                                            (!isSuperAdmin ||
                                                _isProcessingBackup)
                                            ? null
                                            : () async {
                                                final confirmed =
                                                    await showAdminConfirmDialog(
                                                      context: context,
                                                      icon: AdminIcons.restore,
                                                      tone: AdminDialogTone
                                                          .danger,
                                                      title:
                                                          'استعادة النسخة الاحتياطية',
                                                      message:
                                                          'سيتم مسح جميع الأكلات الموجودة حالياً في الخزنة واستبدالها بالكامل بالنسخة الاحتياطية المرفوعة مسبقاً.',
                                                      note: AdminDialogNote(
                                                        tone: AdminDialogTone
                                                            .danger,
                                                        icon:
                                                            AdminIcons.warning,
                                                        badge:
                                                            'لا يمكن التراجع',
                                                        title:
                                                            'الخزنة الحالية سيتم استبدالها بالكامل',
                                                      ),
                                                      confirmLabel:
                                                          'استعادة الآن',
                                                      confirmIcon:
                                                          AdminIcons.restore,
                                                    );
                                                if (!confirmed) return;
                                                setState(
                                                  () => _isProcessingBackup =
                                                      true,
                                                );
                                                try {
                                                  await ref
                                                      .read(
                                                        vaultAdminRepositoryProvider,
                                                      )
                                                      .restoreVault();
                                                  if (mounted) {
                                                    showAdminToast(
                                                      context,
                                                      message:
                                                          'تمت الاستعادة بنجاح',
                                                      subtitle:
                                                          'تم استبدال الخزنة بالنسخة الاحتياطية',
                                                      kind: AdminToastKind
                                                          .success,
                                                    );
                                                  }
                                                } catch (e) {
                                                  if (mounted) {
                                                    showAdminToast(
                                                      context,
                                                      message:
                                                          'خطأ أثناء الاستعادة',
                                                      subtitle: e.toString(),
                                                      kind:
                                                          AdminToastKind.error,
                                                    );
                                                  }
                                                } finally {
                                                  if (mounted) {
                                                    setState(
                                                      () =>
                                                          _isProcessingBackup =
                                                              false,
                                                    );
                                                  }
                                                }
                                              },
                                        style: OutlinedButton.styleFrom(
                                          foregroundColor: p.nileInk,
                                          side: BorderSide(
                                            color: p.nileSolid.withValues(
                                              alpha: 0.5,
                                            ),
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              AdminRadii.md,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                        ),
                                        icon: _isProcessingBackup
                                            ? const SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                    ),
                                              )
                                            : const Icon(
                                                AdminIcons.restore,
                                                size: 15,
                                              ),
                                        label: Text(
                                          'استعادة',
                                          style: adminText(size: 13),
                                        ),
                                      ),
                                    ),
                                    const SizedBox(width: 10),
                                    Expanded(
                                      child: FilledButton.icon(
                                        onPressed:
                                            (!isSuperAdmin ||
                                                _isProcessingBackup)
                                            ? null
                                            : () async {
                                                final confirmed =
                                                    await showAdminConfirmDialog(
                                                      context: context,
                                                      icon: AdminIcons.backup,
                                                      tone:
                                                          AdminDialogTone.info,
                                                      title:
                                                          'رفع نسخة احتياطية',
                                                      message:
                                                          'سيتم مسح النسخة الاحتياطية القديمة بالكامل واستبدالها بالبيانات الحالية الموجودة في الخزنة.',
                                                      note: AdminDialogNote(
                                                        tone: AdminDialogTone
                                                            .info,
                                                        icon: AdminIcons.info,
                                                        title:
                                                            'النسخة القديمة ستُستبدل بالبيانات الحالية',
                                                      ),
                                                      confirmLabel:
                                                          'رفع النسخة',
                                                      confirmIcon:
                                                          AdminIcons.backup,
                                                    );
                                                if (!confirmed) return;
                                                setState(
                                                  () => _isProcessingBackup =
                                                      true,
                                                );
                                                try {
                                                  await ref
                                                      .read(
                                                        vaultAdminRepositoryProvider,
                                                      )
                                                      .backupVault();
                                                  if (mounted) {
                                                    showAdminToast(
                                                      context,
                                                      message:
                                                          'تم رفع النسخة الاحتياطية',
                                                      subtitle:
                                                          'البيانات الحالية محفوظة بأمان',
                                                      kind: AdminToastKind
                                                          .success,
                                                    );
                                                  }
                                                } catch (e) {
                                                  if (mounted) {
                                                    showAdminToast(
                                                      context,
                                                      message:
                                                          'خطأ أثناء النسخ الاحتياطي',
                                                      subtitle: e.toString(),
                                                      kind:
                                                          AdminToastKind.error,
                                                    );
                                                  }
                                                } finally {
                                                  if (mounted) {
                                                    setState(
                                                      () =>
                                                          _isProcessingBackup =
                                                              false,
                                                    );
                                                  }
                                                }
                                              },
                                        style: FilledButton.styleFrom(
                                          backgroundColor: p.nileSolid,
                                          foregroundColor: p.onSolid(
                                            p.nileSolid,
                                          ),
                                          shape: RoundedRectangleBorder(
                                            borderRadius: BorderRadius.circular(
                                              AdminRadii.md,
                                            ),
                                          ),
                                          padding: const EdgeInsets.symmetric(
                                            vertical: 12,
                                          ),
                                        ),
                                        icon: _isProcessingBackup
                                            ? SizedBox(
                                                width: 14,
                                                height: 14,
                                                child:
                                                    CircularProgressIndicator(
                                                      strokeWidth: 2,
                                                      color: p.onSolid(
                                                        p.nileSolid,
                                                      ),
                                                    ),
                                              )
                                            : const Icon(
                                                AdminIcons.backup,
                                                size: 15,
                                              ),
                                        label: Text(
                                          'نسخ احتياطي',
                                          style: adminText(size: 13),
                                        ),
                                      ),
                                    ),
                                  ],
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSettingsTile({
    required AdminPalette p,
    required IconData icon,
    required Color iconColor,
    required Color iconBg,
    required String title,
    required String subtitle,
    required Widget trailing,
    bool locked = false,
  }) {
    return Opacity(
      opacity: locked ? 0.48 : 1.0,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        child: Row(
          children: [
            _IconTile(
              icon: icon,
              fg: locked ? p.inkFaint : iconColor,
              bg: locked ? p.surfaceSunken : iconBg,
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Text(
                        title,
                        style: adminText(
                          size: 14,
                          weight: FontWeight.bold,
                          color: locked ? p.inkMuted : p.ink,
                        ),
                      ),
                      if (locked) ...[
                        const SizedBox(width: 8),
                        _Pill(
                          label: 'Super Admin فقط',
                          bg: p.surfaceSunken,
                          fg: p.inkFaint,
                          icon: AdminIcons.lock,
                        ),
                      ],
                    ],
                  ),
                  const SizedBox(height: 3),
                  Text(subtitle, style: adminText(size: 12, color: p.inkMuted)),
                ],
              ),
            ),
            const SizedBox(width: 12),
            trailing,
          ],
        ),
      ),
    );
  }

  // ---------------------------------------------------------------------
  // بطاقة المظهر: الوضع النهاري / الداكن / النظام
  // ---------------------------------------------------------------------
  Widget _buildAppearanceCard(AdminPalette p) {
    final current = ref.watch(themeModePreferenceProvider);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: p.panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Row(
            children: [
              _IconTile(
                icon: AdminIcons.palette,
                fg: p.claySolid,
                bg: p.claySoft,
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'وضع العرض',
                      style: adminText(
                        size: 14,
                        weight: FontWeight.bold,
                        color: p.ink,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      'اختر بين الوضع النهاري والداكن أو اتبع إعدادات الجهاز',
                      style: adminText(size: 12, color: p.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            children: [
              _appearanceOption(
                p,
                AppThemeModePreference.light,
                'نهاري',
                AdminIcons.lightMode,
                current,
              ),
              const SizedBox(width: 10),
              _appearanceOption(
                p,
                AppThemeModePreference.dark,
                'داكن',
                AdminIcons.darkMode,
                current,
              ),
              const SizedBox(width: 10),
              _appearanceOption(
                p,
                AppThemeModePreference.system,
                'النظام',
                AdminIcons.autoMode,
                current,
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _appearanceOption(
    AdminPalette p,
    AppThemeModePreference mode,
    String label,
    IconData icon,
    AppThemeModePreference current,
  ) {
    final selected = mode == current;
    return Expanded(
      child: Material(
        color: selected ? p.claySoft : p.surfaceAlt,
        borderRadius: BorderRadius.circular(AdminRadii.md),
        child: InkWell(
          borderRadius: BorderRadius.circular(AdminRadii.md),
          onTap: () => _setThemeMode(mode),
          child: Container(
            padding: const EdgeInsets.symmetric(vertical: 14),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AdminRadii.md),
              border: Border.all(
                color: selected
                    ? p.clay.withValues(alpha: 0.55)
                    : Colors.transparent,
              ),
            ),
            child: Column(
              children: [
                Icon(
                  icon,
                  size: 20,
                  color: selected ? p.onClaySoft : p.inkMuted,
                ),
                const SizedBox(height: 6),
                Text(
                  label,
                  style: adminText(
                    size: 12,
                    weight: selected ? FontWeight.bold : FontWeight.w500,
                    color: selected ? p.onClaySoft : p.inkMuted,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Future<void> _setThemeMode(AppThemeModePreference mode) async {
    try {
      await ref.read(settingsControllerProvider.notifier).updateThemeMode(mode);
      if (!mounted) return;
      showAdminToast(
        context,
        message: 'تم التبديل إلى ${_themeModeLabel(mode)}',
        kind: AdminToastKind.success,
      );
    } catch (_) {
      if (!mounted) return;
      showAdminToast(
        context,
        message: 'تعذر تغيير وضع العرض',
        subtitle: 'حاول مرة أخرى',
        kind: AdminToastKind.error,
      );
    }
  }

  void _showSystemConfigDialog(AdminPalette p) {
    showAdminDialog(
      context: context,
      builder: (dialogCtx) {
        return Consumer(
          builder: (ctx, ref, child) {
            final configAsync = ref.watch(systemConfigStreamProvider);

            return configAsync.when(
              loading: () => const AdminDialogShell(
                icon: AdminIcons.settings,
                tone: AdminDialogTone.brand,
                title: 'إعدادات النظام',
                child: SizedBox(
                  height: 100,
                  child: Center(child: CircularProgressIndicator()),
                ),
              ),
              error: (e, _) => AdminDialogShell(
                icon: AdminIcons.settings,
                tone: AdminDialogTone.brand,
                title: 'إعدادات النظام',
                child: AdminDialogBanner(
                  tone: AdminDialogTone.danger,
                  icon: AdminIcons.warning,
                  message: 'تعذر تحميل الإعدادات: $e',
                ),
              ),
              data: (config) {
                int cooldownDays = config?['cooldownDays'] ?? 14;
                String minAppVersion = config?['minAppVersion'] ?? '1.0.0';
                String announcement = config?['announcement'] ?? '';
                bool saving = false;

                return StatefulBuilder(
                  builder: (ctx, setState) => AdminDialogShell(
                    icon: AdminIcons.settings,
                    tone: AdminDialogTone.brand,
                    title: 'إعدادات النظام',
                    subtitle: 'أيام التبريد، إصدار التطبيق، والإعلان العام',
                    maxWidth: 470,
                    actions: [
                      AdminDialogButtons.ghost(
                        p,
                        label: 'إلغاء',
                        onPressed: saving
                            ? null
                            : () => Navigator.of(ctx).pop(),
                      ),
                      AdminDialogButtons.primary(
                        p,
                        label: 'حفظ التغييرات',
                        tone: AdminDialogTone.brand,
                        icon: AdminIcons.verified,
                        loading: saving,
                        onPressed: saving
                            ? null
                            : () async {
                                setState(() => saving = true);
                                final progress = AdminToast.loading(
                                  message: 'جارٍ حفظ إعدادات النظام',
                                );
                                try {
                                  await ref
                                      .read(adminSystemConfigRepositoryProvider)
                                      .updateSystemConfig(
                                        cooldownDays: cooldownDays,
                                        minAppVersion: minAppVersion,
                                        announcement: announcement,
                                      );
                                  progress.resolve(
                                    message: 'تم حفظ إعدادات النظام',
                                    subtitle:
                                        'التغييرات سارية على كل الأجهزة الآن',
                                    kind: AdminToastKind.success,
                                  );
                                  if (ctx.mounted) Navigator.of(ctx).pop();
                                } catch (e) {
                                  progress.resolve(
                                    message: 'تعذر حفظ إعدادات النظام',
                                    subtitle: e.toString(),
                                    kind: AdminToastKind.error,
                                  );
                                  if (ctx.mounted) {
                                    setState(() => saving = false);
                                  }
                                }
                              },
                      ),
                    ],
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        Container(
                          padding: const EdgeInsetsDirectional.fromSTEB(
                            14,
                            12,
                            14,
                            6,
                          ),
                          decoration: p.panel(
                            color: p.surfaceAlt,
                            radius: AdminRadii.md,
                          ),
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            crossAxisAlignment: CrossAxisAlignment.stretch,
                            children: [
                              Row(
                                children: [
                                  Expanded(
                                    child: Text(
                                      'أيام التبريد بين الاقتراحات',
                                      style: adminText(
                                        size: 13,
                                        weight: FontWeight.bold,
                                        color: p.ink,
                                      ),
                                    ),
                                  ),
                                  _Pill(
                                    label: '$cooldownDays يوم',
                                    bg: p.claySoft,
                                    fg: p.onClaySoft,
                                    icon: AdminIcons.time,
                                  ),
                                ],
                              ),
                              Slider(
                                value: cooldownDays.toDouble(),
                                min: 3,
                                max: 30,
                                divisions: 27,
                                label: '$cooldownDays يوم',
                                activeColor: p.clay,
                                onChanged: (v) =>
                                    setState(() => cooldownDays = v.toInt()),
                              ),
                              Text(
                                'المدة التي ينتظرها المستخدم قبل أن يستطيع اقتراح أكلة جديدة مرة أخرى',
                                style: adminText(
                                  size: 11.5,
                                  color: p.inkFaint,
                                  height: 1.6,
                                ),
                              ),
                              const SizedBox(height: 6),
                            ],
                          ),
                        ),
                        const SizedBox(height: 14),
                        TextFormField(
                          initialValue: minAppVersion,
                          style: adminText(color: p.ink),
                          decoration: adminFieldDeco(
                            p,
                            label: 'الحد الأدنى لإصدار التطبيق',
                            hint: 'مثال: 1.4.2',
                            icon: AdminIcons.update,
                          ),
                          onChanged: (v) => minAppVersion = v,
                        ),
                        const SizedBox(height: 12),
                        TextFormField(
                          initialValue: announcement,
                          maxLines: 3,
                          style: adminText(color: p.ink),
                          decoration: adminFieldDeco(
                            p,
                            label: 'إعلان عام للمستخدمين',
                            hint: 'رسالة تظهر لجميع المستخدمين داخل التطبيق',
                            icon: AdminIcons.campaign,
                          ),
                          onChanged: (v) => announcement = v,
                        ),
                      ],
                    ),
                  ),
                );
              },
            );
          },
        );
      },
    );
  }

  /// The roster is a live snapshot, so a changed role erases the fact that it
  /// ever changed. This streams the append-only `admin_audit` entries under it
  /// so "who granted what, when" stays readable in the same place it happened.
  Widget _adminAuditSection(AdminSecurityService service) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const SizedBox(height: 16),
        const AdminDialogPanel(
          icon: AdminIcons.time,
          text: 'سجل تغييرات الصلاحيات (أحدث 10 عمليات)',
        ),
        const SizedBox(height: 8),
        StreamBuilder<List<Map<String, dynamic>>>(
          stream: service.streamAuditLog(limit: 10),
          builder: (context, snapshot) {
            if (snapshot.hasError) {
              return AdminDialogPanel(
                icon: AdminIcons.warning,
                text: 'تعذر تحميل السجل: ${snapshot.error}',
              );
            }
            final entries = snapshot.data ?? [];
            if (entries.isEmpty) {
              return const AdminDialogPanel(text: 'لا تغييرات مسجلة بعد.');
            }
            return Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final entry in entries)
                  Padding(
                    padding: const EdgeInsets.only(bottom: 6),
                    child: AdminDialogPanel(
                      icon: _auditIconFor(entry['action'] as String?),
                      text: _auditLine(entry),
                    ),
                  ),
              ],
            );
          },
        ),
      ],
    );
  }

  IconData _auditIconFor(String? action) => switch (action) {
    'add' => AdminIcons.adminAdd,
    'set_role' => AdminIcons.edit,
    'remove' => AdminIcons.delete,
    _ => AdminIcons.info,
  };

  String _auditLine(Map<String, dynamic> entry) {
    final target = entry['target'] as String? ?? 'عنوان غير معروف';
    final actor = entry['actor'] as String?;
    final role = entry['role'] as String?;
    final roleLabel = role == null ? '' : adminRoleMeta(role).label;

    final body = switch (entry['action'] as String?) {
      'add' => 'أضاف $target بصلاحية $roleLabel',
      'set_role' => 'غيّر صلاحية $target إلى $roleLabel',
      'remove' => 'أزال $target',
      _ => target,
    };

    final at = (entry['at'] as Timestamp?)?.toDate();
    final when = at == null
        ? 'قبل لحظات'
        : '${at.day.toString().padLeft(2, '0')}/'
              '${at.month.toString().padLeft(2, '0')} '
              '${at.hour.toString().padLeft(2, '0')}:'
              '${at.minute.toString().padLeft(2, '0')}';

    return actor == null || actor.isEmpty
        ? '$body — $when'
        : '$body بواسطة $actor — $when';
  }

  void _showAdminManagementDialog(AdminPalette p, String? currentUserEmail) {
    showAdminDialog(
      context: context,
      builder: (context) {
        return Consumer(
          builder: (ctx, ref, child) {
            final service = ref.read(adminSecurityServiceProvider);

            return AdminDialogShell(
              icon: AdminIcons.admins,
              tone: AdminDialogTone.plum,
              title: 'إدارة المشرفين',
              subtitle: 'حدد صلاحيات من يمكنه الدخول إلى لوحة التحكم',
              maxWidth: 540,
              child: StreamBuilder<List<Map<String, dynamic>>>(
                stream: service.streamAdmins(),
                builder: (context, snapshot) {
                  if (snapshot.connectionState == ConnectionState.waiting) {
                    return const Padding(
                      padding: EdgeInsets.symmetric(vertical: 44),
                      child: Center(child: CircularProgressIndicator()),
                    );
                  }
                  if (snapshot.hasError) {
                    return AdminDialogBanner(
                      tone: AdminDialogTone.danger,
                      icon: AdminIcons.warning,
                      message: 'تعذر تحميل قائمة المشرفين: ${snapshot.error}',
                    );
                  }

                  final admins = snapshot.data ?? [];

                  Widget buildRow(Map<String, dynamic> admin) {
                    final email = admin['email'] as String? ?? 'مجهول';
                    final role = admin['role'] as String? ?? 'viewing_admin';
                    final isMe =
                        email.toLowerCase() == currentUserEmail?.toLowerCase();
                    // Legacy 'admin' roles are displayed as editing admins.
                    final displayRole = role == 'admin'
                        ? 'editing_admin'
                        : role;
                    final meta = adminRoleMeta(displayRole);
                    // Whether this address ever actually logged in. A grant whose
                    // owner never signed in is almost always a typo'd address: the
                    // browser cannot ask Firebase if an account exists any more, so
                    // this is the honest signal rather than a claimed verification.
                    final everSignedIn = admin['lastSeenAt'] != null;
                    final tone = adminToneColors(p, meta.tone);

                    return Container(
                      padding: const EdgeInsetsDirectional.fromSTEB(
                        10,
                        9,
                        6,
                        9,
                      ),
                      decoration: p.panel(
                        color: p.surfaceAlt,
                        radius: AdminRadii.md,
                      ),
                      child: Row(
                        children: [
                          Container(
                            width: 38,
                            height: 38,
                            alignment: Alignment.center,
                            decoration: BoxDecoration(
                              color: tone.soft,
                              shape: BoxShape.circle,
                            ),
                            child: Text(
                              email.isEmpty
                                  ? '?'
                                  : email.substring(0, 1).toUpperCase(),
                              style: adminText(
                                size: 15,
                                weight: FontWeight.w800,
                                color: tone.ink,
                              ),
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              mainAxisSize: MainAxisSize.min,
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  email,
                                  style: adminText(
                                    size: 13,
                                    weight: FontWeight.w700,
                                    color: p.ink,
                                  ),
                                  maxLines: 1,
                                  overflow: TextOverflow.ellipsis,
                                ),
                                const SizedBox(height: 4),
                                Row(
                                  children: [
                                    AdminRoleBadge(role: displayRole),
                                    if (!everSignedIn) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        'لم يسجّل دخوله بعد',
                                        style: adminText(
                                          size: 11,
                                          weight: FontWeight.w700,
                                          color: p.inkFaint,
                                        ),
                                      ),
                                    ],
                                    if (isMe) ...[
                                      const SizedBox(width: 6),
                                      Text(
                                        'أنت',
                                        style: adminText(
                                          size: 11,
                                          color: p.inkFaint,
                                        ),
                                      ),
                                    ],
                                  ],
                                ),
                              ],
                            ),
                          ),
                          PopupMenuButton<String>(
                            enabled: !isMe,
                            tooltip: isMe
                                ? 'لا يمكنك تغيير صلاحية حسابك'
                                : 'تغيير الصلاحية',
                            position: PopupMenuPosition.under,
                            color: p.surface,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(
                                AdminRadii.md,
                              ),
                              side: BorderSide(color: p.border),
                            ),
                            icon: Icon(
                              AdminIcons.expand,
                              size: 18,
                              color: isMe ? p.inkFaint : p.inkMuted,
                            ),
                            onSelected: (newRole) async {
                              final progress = AdminToast.loading(
                                message: 'جارٍ تحديث صلاحية $email',
                              );
                              try {
                                await service.setAdminRole(email, newRole);
                                progress.resolve(
                                  message: 'تم تحديث صلاحية $email',
                                  subtitle:
                                      'الصلاحية الجديدة: ${adminRoleMeta(newRole).label}',
                                  kind: AdminToastKind.success,
                                );
                              } catch (e) {
                                progress.resolve(
                                  message: 'تعذر تحديث الصلاحية',
                                  subtitle: e.toString(),
                                  kind: AdminToastKind.error,
                                );
                              }
                            },
                            itemBuilder: (context) => [
                              for (final option in const [
                                'viewing_admin',
                                'editing_admin',
                                'super_admin',
                              ])
                                PopupMenuItem<String>(
                                  value: option,
                                  child: Row(
                                    children: [
                                      Icon(
                                        adminRoleMeta(option).icon,
                                        size: 16,
                                        color: option == displayRole
                                            ? p.clay
                                            : p.inkMuted,
                                      ),
                                      const SizedBox(width: 10),
                                      Text(
                                        adminRoleMeta(option).label,
                                        style: adminText(
                                          size: 12.5,
                                          weight: option == displayRole
                                              ? FontWeight.w700
                                              : FontWeight.w500,
                                          color: option == displayRole
                                              ? p.clay
                                              : p.ink,
                                        ),
                                      ),
                                      if (option == displayRole) ...[
                                        const SizedBox(width: 12),
                                        Icon(
                                          AdminIcons.success,
                                          size: 15,
                                          color: p.clay,
                                        ),
                                      ],
                                    ],
                                  ),
                                ),
                            ],
                          ),
                          if (!isMe)
                            IconButton(
                              tooltip: 'إزالة المشرف',
                              visualDensity: VisualDensity.compact,
                              icon: Icon(
                                AdminIcons.adminRemove,
                                size: 19,
                                color: p.chiliSolid,
                              ),
                              onPressed: () async {
                                final confirmed = await showAdminConfirmDialog(
                                  context: context,
                                  icon: AdminIcons.adminRemove,
                                  tone: AdminDialogTone.danger,
                                  title: 'إزالة مشرف',
                                  message:
                                      'سيفقد هذا الحساب صلاحية الدخول إلى '
                                      'لوحة التحكم فوراً.',
                                  note: AdminDialogNote(
                                    tone: AdminDialogTone.danger,
                                    icon: AdminIcons.email,
                                    title: email,
                                    subtitle: meta.label,
                                  ),
                                  confirmLabel: 'إزالة',
                                  confirmIcon: AdminIcons.adminRemove,
                                );
                                if (confirmed) {
                                  final progress = AdminToast.loading(
                                    message: 'جارٍ إزالة $email',
                                  );
                                  try {
                                    await service.removeAdmin(email);
                                    progress.resolve(
                                      message: 'تم إزالة المشرف $email',
                                      subtitle:
                                          'فقد صلاحية الدخول إلى لوحة التحكم فوراً',
                                      kind: AdminToastKind.warning,
                                    );
                                  } catch (e) {
                                    progress.resolve(
                                      message: 'تعذر إزالة المشرف',
                                      subtitle: e.toString(),
                                      kind: AdminToastKind.error,
                                    );
                                  }
                                }
                              },
                            ),
                        ],
                      ),
                    );
                  }

                  return Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      AdminDialogButtons.tonal(
                        p,
                        label: 'إضافة مشرف جديد',
                        tone: AdminDialogTone.brand,
                        icon: AdminIcons.adminAdd,
                        onPressed: () async {
                          String selectedRole = 'viewing_admin';
                          final emailCtrl = TextEditingController();

                          final addResult = await showAdminDialog<(String, String)>(
                            context: context,
                            builder: (ctx) {
                              return StatefulBuilder(
                                builder: (context, setState) {
                                  return AdminDialogShell(
                                    icon: AdminIcons.adminAdd,
                                    tone: AdminDialogTone.brand,
                                    title: 'إضافة مشرف',
                                    subtitle:
                                        'سيتم منح هذا البريد صلاحية الوصول '
                                        'إلى لوحة التحكم',
                                    maxWidth: 430,
                                    actions: [
                                      AdminDialogButtons.ghost(
                                        p,
                                        label: 'إلغاء',
                                        onPressed: () =>
                                            Navigator.of(ctx).pop(),
                                      ),
                                      AdminDialogButtons.primary(
                                        p,
                                        label: 'إضافة',
                                        tone: AdminDialogTone.brand,
                                        // `verified` implied the address had been
                                        // confirmed; nothing here confirms
                                        // anything, so the button says what it does.
                                        icon: AdminIcons.add,
                                        onPressed:
                                            AdminSecurityService.isUsableEmail(
                                              emailCtrl.text,
                                            )
                                            ? () => Navigator.of(ctx).pop((
                                                emailCtrl.text
                                                    .trim()
                                                    .toLowerCase(),
                                                selectedRole,
                                              ))
                                            : null,
                                      ),
                                    ],
                                    child: Column(
                                      mainAxisSize: MainAxisSize.min,
                                      children: [
                                        TextField(
                                          controller: emailCtrl,
                                          style: adminText(color: p.ink),
                                          keyboardType:
                                              TextInputType.emailAddress,
                                          onChanged: (_) => setState(() {}),
                                          decoration: adminFieldDeco(
                                            p,
                                            label: 'البريد الإلكتروني',
                                            hint: 'name@example.com',
                                            icon: AdminIcons.email,
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        DropdownButtonFormField<String>(
                                          initialValue: selectedRole,
                                          dropdownColor: p.surface,
                                          borderRadius: BorderRadius.circular(
                                            AdminRadii.md,
                                          ),
                                          style: adminText(color: p.ink),
                                          icon: Icon(
                                            AdminIcons.expand,
                                            size: 18,
                                            color: p.inkFaint,
                                          ),
                                          items: [
                                            for (final option in const [
                                              'viewing_admin',
                                              'editing_admin',
                                              'super_admin',
                                            ])
                                              DropdownMenuItem(
                                                value: option,
                                                child: Text(
                                                  '${adminRoleMeta(option).label}'
                                                  ' (${adminRoleMeta(option).short})',
                                                  style: adminText(
                                                    color: p.ink,
                                                  ),
                                                ),
                                              ),
                                          ],
                                          onChanged: (val) {
                                            if (val != null) {
                                              setState(
                                                () => selectedRole = val,
                                              );
                                            }
                                          },
                                          decoration: adminFieldDeco(
                                            p,
                                            label: 'الصلاحية',
                                            icon: AdminIcons.role,
                                          ),
                                        ),
                                        const SizedBox(height: 14),
                                        const AdminDialogPanel(
                                          icon: AdminIcons.info,
                                          text:
                                              'يمكنك تغيير الصلاحية أو إزالة '
                                              'المشرف في أي وقت من نفس الشاشة.',
                                        ),
                                      ],
                                    ),
                                  );
                                },
                              );
                            },
                          );
                          emailCtrl.dispose();
                          if (addResult != null && addResult.$1.isNotEmpty) {
                            final progress = AdminToast.loading(
                              message: 'جارٍ إضافة ${addResult.$1} للمشرفين',
                            );
                            try {
                              await service.seedAdmin(
                                email: addResult.$1,
                                role: addResult.$2,
                              );
                              progress.resolve(
                                message: 'تم منح الوصول لـ ${addResult.$1}',
                                subtitle:
                                    'الصلاحية: ${adminRoleMeta(addResult.$2).label}'
                                    ' — العنوان بيتأكد أول ما يسجّل الدخول فعلًا',
                                kind: AdminToastKind.success,
                              );
                            } catch (e) {
                              progress.resolve(
                                message: 'تعذر إضافة المشرف',
                                subtitle: e.toString(),
                                kind: AdminToastKind.error,
                              );
                            }
                          }
                        },
                      ),
                      const SizedBox(height: 14),
                      if (admins.isEmpty)
                        const AdminDialogPanel(
                          icon: AdminIcons.admins,
                          text:
                              'لا يوجد مشرفون بعد. أضف أول مشرف من الزر '
                              'بالأعلى.',
                        )
                      else
                        for (var i = 0; i < admins.length; i++) ...[
                          if (i > 0) const SizedBox(height: 8),
                          buildRow(admins[i]),
                        ],
                      _adminAuditSection(service),
                    ],
                  );
                },
              ),
            );
          },
        );
      },
    );
  }
}

/// =============================== Sidebar ===============================
class _Sidebar extends StatelessWidget {
  final double width;
  final bool collapsed;
  final bool animate;
  final int selectedIndex;
  final int pendingCount;
  final ValueChanged<int> onSelect;
  final VoidCallback onToggleCollapsed;

  const _Sidebar({
    required this.width,
    required this.collapsed,
    required this.animate,
    required this.selectedIndex,
    required this.pendingCount,
    required this.onSelect,
    required this.onToggleCollapsed,
  });

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    return AnimatedContainer(
      duration: animate ? _sidebarSlide : Duration.zero,
      curve: Curves.easeOutCubic,
      width: width,
      decoration: BoxDecoration(
        color: p.surface,
        border: BorderDirectional(end: BorderSide(color: p.border)),
      ),
      child: LayoutBuilder(
        builder: (context, constraints) {
          // Hold the content at its target width while the panel slides so the
          // edge reveals it instead of reflowing every animation frame.
          return ClipRect(
            child: OverflowBox(
              alignment: AlignmentDirectional.centerStart,
              minWidth: 0,
              maxWidth: double.infinity,
              child: SizedBox(
                width: width,
                height: constraints.maxHeight,
                child: collapsed
                    ? _buildRail(context)
                    : _buildPanel(context, p),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildPanel(BuildContext context, AdminPalette p) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(20, 18, 20, 10),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              _brandLogo(),
              const SizedBox(width: 10),
              Expanded(
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Image.asset(
                      'assets/icons/brand_sparkles.png',
                      height: 56,
                      fit: BoxFit.fill,
                    ),
                    Image.asset(
                      'assets/icons/brand_name.png',
                      height: 54,
                      fit: BoxFit.contain,
                      alignment: AlignmentDirectional.centerStart,
                      color: p.isDark ? Colors.white : null,
                      colorBlendMode: p.isDark ? BlendMode.srcIn : null,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 20),
          child: SizedBox(
            width: 48,
            child: Center(
              child: _slideButton(AdminIcons.collapseRail, 'طي القائمة'),
            ),
          ),
        ),
        const SizedBox(height: 16),
        _navGroupLabel(p, 'مساحة العمل'),
        _navItem(context, AdminIcons.dashboard, 'الرئيسية', 0),
        _navItem(
          context,
          AdminIcons.suggestions,
          'الاقتراحات',
          1,
          badge: pendingCount,
        ),
        _navDivider(p),
        _navGroupLabel(p, 'إدارة النظام'),
        _navItem(context, AdminIcons.notifications, 'الإشعارات', 2),
        _navItem(context, AdminIcons.settings, 'الإعدادات', 3),
        const Spacer(),
        Padding(
          padding: const EdgeInsets.fromLTRB(10, 0, 10, 0),
          child: Align(
            alignment: Alignment.center,
            child: Opacity(
              opacity: p.isDark ? 0.70 : 1.0,
              child: Image.asset(
                'assets/icons/teacup.png',
                width: 150,
                fit: BoxFit.contain,
                errorBuilder: (_, _, _) => const SizedBox.shrink(),
              ),
            ),
          ),
        ),
        const Spacer(),
      ],
    );
  }

  Widget _buildRail(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const SizedBox(height: 16),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: _brandLogo(),
        ),
        const SizedBox(height: 6),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 15),
          child: SizedBox(
            width: 48,
            child: Center(
              child: _slideButton(AdminIcons.expandRail, 'إظهار القائمة'),
            ),
          ),
        ),
        const SizedBox(height: 14),
        _railItem(context, AdminIcons.dashboard, 'الرئيسية', 0),
        _railItem(
          context,
          AdminIcons.suggestions,
          'الاقتراحات',
          1,
          badge: pendingCount,
        ),
        _railItem(context, AdminIcons.notifications, 'الإشعارات', 2),
        _railItem(context, AdminIcons.settings, 'الإعدادات', 3),
        const Spacer(),
      ],
    );
  }

  Widget _brandLogo() {
    return SizedBox(
      width: 48,
      height: 48,
      child: Image.asset('assets/icons/brand_icon.png', fit: BoxFit.contain),
    );
  }

  Widget _slideButton(IconData icon, String tooltip) {
    return AdminIconChip(
      icon: icon,
      tooltip: tooltip,
      onTap: onToggleCollapsed,
    );
  }

  Widget _navGroupLabel(AdminPalette p, String label) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 0, 20, 9),
      child: Text(
        label,
        style: adminText(
          size: 11,
          weight: FontWeight.w600,
          color: p.inkFaint,
          letterSpacing: 0.2,
        ),
      ),
    );
  }

  Widget _navDivider(AdminPalette p) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Container(height: 1, color: p.border),
    );
  }

  Widget _navItem(
    BuildContext context,
    IconData icon,
    String label,
    int index, {
    int badge = 0,
  }) {
    final p = AdminPalette.of(context);
    final isSelected = selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 3),
      child: Material(
        color: isSelected ? p.claySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(AdminRadii.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AdminRadii.sm),
          hoverColor: p.surfaceAlt,
          onTap: () => onSelect(index),
          child: Stack(
            children: [
              if (isSelected)
                PositionedDirectional(
                  start: 0,
                  top: 12,
                  child: Container(
                    width: 3,
                    height: 21,
                    decoration: BoxDecoration(
                      color: p.clay,
                      borderRadius: BorderRadius.circular(3),
                    ),
                  ),
                ),
              Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 11,
                ),
                child: Row(
                  children: [
                    Icon(
                      icon,
                      size: 20,
                      color: isSelected ? p.onClaySoft : p.inkMuted,
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text(
                        label,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: adminText(
                          size: 13.5,
                          weight: isSelected
                              ? FontWeight.w600
                              : FontWeight.w500,
                          color: isSelected ? p.onClaySoft : p.inkMuted,
                        ),
                      ),
                    ),
                    if (badge > 0)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 7,
                          vertical: 2,
                        ),
                        decoration: BoxDecoration(
                          color: p.honeySoft,
                          borderRadius: BorderRadius.circular(5),
                        ),
                        child: Text(
                          '$badge',
                          style: adminLatinText(
                            size: 11,
                            weight: FontWeight.w600,
                            color: p.honeyInk,
                          ),
                        ),
                      ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _railItem(
    BuildContext context,
    IconData icon,
    String label,
    int index, {
    int badge = 0,
  }) {
    final p = AdminPalette.of(context);
    final isSelected = selectedIndex == index;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 15, vertical: 3),
      child: Material(
        color: isSelected ? p.claySoft : Colors.transparent,
        borderRadius: BorderRadius.circular(AdminRadii.md),
        child: Tooltip(
          message: label,
          child: InkWell(
            borderRadius: BorderRadius.circular(AdminRadii.md),
            onTap: () => onSelect(index),
            child: SizedBox(
              width: 48,
              height: 46,
              child: Stack(
                alignment: Alignment.center,
                clipBehavior: Clip.none,
                children: [
                  Icon(
                    icon,
                    size: 20,
                    color: isSelected ? p.onClaySoft : p.inkMuted,
                  ),
                  if (badge > 0)
                    Positioned(
                      top: 7,
                      left: 2,
                      child: Container(
                        constraints: const BoxConstraints(minWidth: 18),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 4,
                          vertical: 1,
                        ),
                        decoration: BoxDecoration(
                          color: p.honeySoft,
                          borderRadius: BorderRadius.circular(AdminRadii.pill),
                        ),
                        child: Text(
                          '$badge',
                          textAlign: TextAlign.center,
                          style: adminLatinText(
                            size: 10,
                            weight: FontWeight.w600,
                            color: p.honeyInk,
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// =============================== Sidebar resize handle ===============================
class _SidebarResizeHandle extends StatefulWidget {
  final bool isDragging;
  final ValueChanged<double> onUpdate;
  final VoidCallback onEnd;

  const _SidebarResizeHandle({
    required this.isDragging,
    required this.onUpdate,
    required this.onEnd,
  });

  @override
  State<_SidebarResizeHandle> createState() => _SidebarResizeHandleState();
}

class _SidebarResizeHandleState extends State<_SidebarResizeHandle> {
  bool _hovering = false;

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    final highlight = widget.isDragging || _hovering;
    // The sidebar is pinned to the RTL start edge, so dragging the handle
    // leftwards is what grows it; under LTR that reading flips.
    final isRtl = Directionality.of(context) == TextDirection.rtl;
    return MouseRegion(
      cursor: SystemMouseCursors.resizeColumn,
      onEnter: (_) => setState(() => _hovering = true),
      onExit: (_) => setState(() => _hovering = false),
      child: GestureDetector(
        behavior: HitTestBehavior.translucent,
        onHorizontalDragUpdate: (d) =>
            widget.onUpdate(isRtl ? -d.delta.dx : d.delta.dx),
        onHorizontalDragEnd: (_) => widget.onEnd(),
        onHorizontalDragCancel: widget.onEnd,
        child: SizedBox(
          width: 12,
          child: Center(
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 120),
              width: 3,
              height: highlight ? 46 : 22,
              decoration: BoxDecoration(
                color: highlight ? p.clay : Colors.transparent,
                borderRadius: BorderRadius.circular(AdminRadii.pill),
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// =============================== Mobile nav ===============================
class _MobileNav extends StatelessWidget {
  final int selectedIndex;
  final int pendingCount;
  final ValueChanged<int> onSelect;

  const _MobileNav({
    required this.selectedIndex,
    required this.pendingCount,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    return NavigationBar(
      selectedIndex: selectedIndex,
      onDestinationSelected: onSelect,
      backgroundColor: p.surface,
      indicatorColor: p.claySoft,
      surfaceTintColor: Colors.transparent,
      height: 68,
      destinations: [
        NavigationDestination(
          icon: Icon(AdminIcons.dashboard, color: p.inkMuted),
          selectedIcon: Icon(AdminIcons.dashboard, color: p.onClaySoft),
          label: 'الرئيسية',
        ),
        NavigationDestination(
          icon: Badge(
            isLabelVisible: pendingCount > 0,
            backgroundColor: p.honeySolid,
            label: Text(
              '$pendingCount',
              style: adminLatinText(size: 10, color: p.onSolid(p.honeySolid)),
            ),
            child: Icon(AdminIcons.suggestions, color: p.inkMuted),
          ),
          selectedIcon: Badge(
            isLabelVisible: pendingCount > 0,
            backgroundColor: p.honeySolid,
            label: Text(
              '$pendingCount',
              style: adminLatinText(size: 10, color: p.onSolid(p.honeySolid)),
            ),
            child: Icon(AdminIcons.suggestions, color: p.onClaySoft),
          ),
          label: 'الاقتراحات',
        ),
        NavigationDestination(
          icon: Icon(AdminIcons.notifications, color: p.inkMuted),
          selectedIcon: Icon(AdminIcons.notifications, color: p.onClaySoft),
          label: 'الإشعارات',
        ),
        NavigationDestination(
          icon: Icon(AdminIcons.settings, color: p.inkMuted),
          selectedIcon: Icon(AdminIcons.settings, color: p.onClaySoft),
          label: 'الإعدادات',
        ),
      ],
    );
  }
}

/// =============================== Top bar ===============================
class _TopBar extends ConsumerWidget {
  final String? userEmail;
  final int pageIndex;
  final TextEditingController searchController;
  final ValueChanged<String> onSearchChanged;
  final VoidCallback? onAddMeal;
  final bool showAddButton;

  /// The field filters the vault grid, so it only earns its place on that page.
  final bool showSearch;

  const _TopBar({
    required this.userEmail,
    required this.pageIndex,
    required this.searchController,
    required this.onSearchChanged,
    required this.onAddMeal,
    required this.showAddButton,
    required this.showSearch,
  });

  Future<void> _toggleTheme(BuildContext context, WidgetRef ref) async {
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final next = isDark
        ? AppThemeModePreference.light
        : AppThemeModePreference.dark;
    try {
      await ref.read(settingsControllerProvider.notifier).updateThemeMode(next);
      if (!context.mounted) return;
      showAdminToast(
        context,
        message: 'تم التبديل إلى ${_themeModeLabel(next)}',
        kind: AdminToastKind.success,
      );
    } catch (_) {
      if (!context.mounted) return;
      showAdminToast(
        context,
        message: 'تعذر تغيير وضع العرض',
        subtitle: 'حاول مرة أخرى',
        kind: AdminToastKind.error,
      );
    }
  }

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final p = AdminPalette.of(context);
    final isDark = Theme.of(context).brightness == Brightness.dark;
    final isMobile = MediaQuery.sizeOf(context).width < 900;
    final meta = _pageMeta[pageIndex];

    final themeButton = IconButton(
      onPressed: () => _toggleTheme(context, ref),
      tooltip: isDark ? 'الوضع النهاري' : 'الوضع الداكن',
      icon: Icon(
        isDark ? AdminIcons.lightMode : AdminIcons.darkMode,
        color: p.inkMuted,
      ),
    );

    final searchField = TextField(
      controller: searchController,
      onChanged: onSearchChanged,
      textDirection: TextDirection.rtl,
      style: adminText(size: 13, color: p.ink),
      decoration: InputDecoration(
        hintText: 'ابحث عن أكلة في الخزنة...',
        hintStyle: adminText(size: 13, color: p.inkFaint),
        prefixIcon: Icon(AdminIcons.search, size: 20, color: p.inkFaint),
        suffixIcon: searchController.text.isEmpty
            ? null
            : IconButton(
                icon: Icon(AdminIcons.close, size: 18, color: p.inkFaint),
                onPressed: () {
                  searchController.clear();
                  onSearchChanged('');
                },
              ),
        filled: true,
        fillColor: p.surfaceAlt,
        isDense: true,
        contentPadding: const EdgeInsets.symmetric(vertical: 13),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AdminRadii.md),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AdminRadii.md),
          borderSide: BorderSide(color: p.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AdminRadii.md),
          borderSide: BorderSide(color: p.clay, width: 1.6),
        ),
      ),
    );

    final addButton = showAddButton
        ? (isMobile
              ? IconButton(
                  onPressed: onAddMeal,
                  icon: const Icon(AdminIcons.add),
                  color: p.onClay,
                  style: IconButton.styleFrom(
                    backgroundColor: p.claySolid,
                    padding: const EdgeInsets.all(12),
                  ),
                )
              : FilledButton.icon(
                  onPressed: onAddMeal,
                  icon: const Icon(AdminIcons.add, size: 18),
                  label: Text(
                    'إضافة أكلة جديدة',
                    style: adminText(size: 13, weight: FontWeight.bold),
                  ),
                  style: FilledButton.styleFrom(
                    backgroundColor: p.claySolid,
                    foregroundColor: p.onClay,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 18,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(AdminRadii.md),
                    ),
                  ),
                ))
        : const SizedBox.shrink();

    final titleBlock = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      children: [
        Text(
          meta.title,
          style: adminText(
            size: 24,
            weight: FontWeight.w600,
            color: p.ink,
            height: 1.35,
            letterSpacing: -0.6,
          ),
        ),
        const SizedBox(height: 3),
        Text(
          meta.subtitle,
          style: adminText(size: 12.5, color: p.inkMuted, height: 1.6),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
      ],
    );

    if (isMobile) {
      return Container(
        padding: const EdgeInsets.fromLTRB(16, 14, 16, 14),
        decoration: BoxDecoration(
          color: p.surface,
          border: Border(bottom: BorderSide(color: p.border)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(child: titleBlock),
                themeButton,
                if (showAddButton) ...[const SizedBox(width: 6), addButton],
              ],
            ),
            if (showSearch) ...[
              const SizedBox(height: 14),
              searchField,
            ],
          ],
        ),
      );
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 26, vertical: 18),
      decoration: BoxDecoration(
        color: p.surface,
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          titleBlock,
          if (showSearch) ...[
            const SizedBox(width: 24),
            Expanded(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 400),
                child: searchField,
              ),
            ),
          ],
          const Spacer(),
          if (showAddButton) ...[
            addButton,
            const SizedBox(width: 14),
          ] else
            const SizedBox(width: 6),
          IconButton(
            onPressed: () => showAdminNotificationCenter(context),
            tooltip: 'مركز الإشعارات',
            icon: Icon(AdminIcons.notificationQuiet, color: p.inkMuted),
          ),
          const SizedBox(width: 6),
          themeButton,
          const SizedBox(width: 6),
          Container(
            padding: const EdgeInsets.all(3),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              border: Border.all(color: p.borderStrong),
            ),
            child: Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                gradient: p.brandGradient,
                shape: BoxShape.circle,
              ),
              child: Icon(
                AdminIcons.person,
                size: 18,
                color: p.onSolid(p.brandGradient.colors.first),
              ),
            ),
          ),
          const SizedBox(width: 10),
          ConstrainedBox(
            constraints: const BoxConstraints(maxWidth: 180),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'المشرف',
                  style: adminText(
                    size: 12,
                    weight: FontWeight.bold,
                    color: p.ink,
                  ),
                ),
                Text(
                  userEmail ?? 'Super Admin',
                  style: adminText(size: 10, color: p.inkMuted),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// =============================== Stat card ===============================
class _StatCard extends StatelessWidget {
  final IconData icon;
  final Color bg;
  final Color accent;
  final String label;
  final String value;
  final String? trend;
  final VoidCallback? onTap;

  const _StatCard({
    required this.icon,
    required this.bg,
    required this.accent,
    required this.label,
    required this.value,
    this.trend,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    return Material(
      color: bg,
      borderRadius: BorderRadius.circular(AdminRadii.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(10),
                    decoration: BoxDecoration(
                      color: p.surface,
                      borderRadius: BorderRadius.circular(AdminRadii.sm),
                    ),
                    child: Icon(icon, color: accent, size: 20),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Text(
                      label,
                      style: adminText(
                        size: 13,
                        weight: FontWeight.w600,
                        color: p.inkMuted,
                      ),
                    ),
                  ),
                  if (onTap != null)
                    Icon(AdminIcons.forward, size: 13, color: accent),
                ],
              ),
              const SizedBox(height: 18),
              Text(
                value,
                style: adminText(
                  size: 36,
                  weight: FontWeight.bold,
                  color: p.ink,
                ),
              ),
              if (trend != null) ...[
                const SizedBox(height: 10),
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 5,
                  ),
                  decoration: BoxDecoration(
                    color: p.surface.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(AdminRadii.pill),
                  ),
                  child: Text(
                    trend!,
                    style: adminText(
                      size: 11,
                      weight: FontWeight.bold,
                      color: accent,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

/// =============================== Category stats ===============================
class _CategoryStatsCard extends StatelessWidget {
  final List<CloudMeal> meals;

  const _CategoryStatsCard({required this.meals});

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);

    final Map<String, int> counts = {};
    for (final m in meals) {
      counts[m.category] = (counts[m.category] ?? 0) + 1;
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final visible = sorted.take(4).toList();
    final total = meals.length;

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.claySoft,
        borderRadius: BorderRadius.circular(AdminRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(AdminRadii.sm),
                ),
                child: Icon(AdminIcons.chart, color: p.onClaySoft, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'توزيع التصنيفات',
                  style: adminText(
                    size: 13,
                    weight: FontWeight.w600,
                    color: p.onClaySoft,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (total == 0)
            Text(
              'لا توجد بيانات',
              style: adminText(size: 14, color: p.onClaySoft),
            )
          else ...[
            ClipRRect(
              borderRadius: BorderRadius.circular(AdminRadii.pill),
              child: SizedBox(
                height: 10,
                child: Row(
                  children: visible
                      .map(
                        (e) => Expanded(
                          flex: e.value,
                          child: Padding(
                            padding: const EdgeInsets.only(left: 2),
                            child: Container(color: _categoryColor(e.key, p)),
                          ),
                        ),
                      )
                      .toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            for (final e in visible) ...[
              Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  children: [
                    Container(
                      width: 9,
                      height: 9,
                      decoration: BoxDecoration(
                        color: _categoryColor(e.key, p),
                        borderRadius: BorderRadius.circular(3),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        _translateCategory(e.key),
                        style: adminText(
                          size: 12,
                          weight: FontWeight.bold,
                          color: p.ink,
                        ),
                      ),
                    ),
                    Text(
                      '${e.value} (${((e.value / total) * 100).toStringAsFixed(0)}%)',
                      style: adminText(size: 11, color: p.inkMuted),
                    ),
                  ],
                ),
              ),
            ],
          ],
        ],
      ),
    );
  }
}

/// =============================== Leaderboard ===============================
class _LeaderboardCard extends StatelessWidget {
  final List<CloudMeal> meals;

  const _LeaderboardCard({required this.meals});

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);

    final Map<String, int> counts = {};
    for (final m in meals) {
      if (m.proposedBy != null && m.proposedBy!.trim().isNotEmpty) {
        counts[m.proposedBy!] = (counts[m.proposedBy!] ?? 0) + 1;
      }
    }
    final sorted = counts.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final top = sorted.take(3).toList();

    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: p.plumSoft,
        borderRadius: BorderRadius.circular(AdminRadii.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(9),
                decoration: BoxDecoration(
                  color: p.surface,
                  borderRadius: BorderRadius.circular(AdminRadii.sm),
                ),
                child: Icon(AdminIcons.trophy, color: p.plumInk, size: 19),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  'بطل المقترحات',
                  style: adminText(
                    size: 13,
                    weight: FontWeight.w600,
                    color: p.plumInk,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 18),
          if (top.isEmpty)
            Text(
              'لا توجد مقترحات معتمدة',
              style: adminText(size: 13, color: p.plumInk),
            )
          else ...[
            Text(
              top.first.key,
              style: adminText(size: 16, weight: FontWeight.bold, color: p.ink),
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 4),
            Text(
              '${top.first.value} مقترحات معتمدة',
              style: adminText(size: 12, color: p.plumInk),
            ),
            if (top.length > 1) ...[
              const SizedBox(height: 14),
              Divider(color: p.plumSolid.withValues(alpha: 0.25), height: 1),
              const SizedBox(height: 12),
              for (var i = 1; i < top.length; i++)
                Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      Container(
                        width: 20,
                        height: 20,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: p.surface,
                          borderRadius: BorderRadius.circular(6),
                        ),
                        child: Text(
                          '${i + 1}',
                          style: adminText(
                            size: 10,
                            weight: FontWeight.bold,
                            color: p.plumInk,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          top[i].key,
                          style: adminText(size: 12, color: p.ink),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ),
                      Text(
                        '${top[i].value}',
                        style: adminText(size: 11, color: p.inkMuted),
                      ),
                    ],
                  ),
                ),
            ],
          ],
        ],
      ),
    );
  }
}

/// =============================== Vault meal card ===============================
class _VaultMealCard extends StatelessWidget {
  final CloudMeal meal;
  final VoidCallback? onEdit;
  final VoidCallback? onDelete;
  final VoidCallback onDetails;

  const _VaultMealCard({
    required this.meal,
    required this.onEdit,
    required this.onDelete,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    final tint = p.proteinTint(meal.proteinType);
    final catColor = _categoryColor(meal.category, p);

    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(AdminRadii.lg),
      clipBehavior: Clip.antiAlias,
      elevation: 0,
      child: InkWell(
        onTap: onDetails,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AdminRadii.lg),
            border: Border.all(color: p.border),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              SizedBox(
                height: 150,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    meal.imageUrl != null && meal.imageUrl!.isNotEmpty
                        ? Image.network(
                            meal.imageUrl!,
                            fit: BoxFit.cover,
                            errorBuilder: (_, _, _) => _fallback(p),
                          )
                        : _fallback(p),
                    Positioned(
                      top: 0,
                      left: 0,
                      right: 0,
                      height: 60,
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          gradient: LinearGradient(
                            colors: [
                              Colors.black.withValues(alpha: 0.45),
                              Colors.transparent,
                            ],
                            begin: Alignment.topCenter,
                            end: Alignment.bottomCenter,
                          ),
                        ),
                      ),
                    ),
                    Positioned(
                      top: 10,
                      right: 10,
                      child: _Pill(
                        label: _translateCategory(meal.category),
                        bg: Colors.black.withValues(alpha: 0.6),
                        fg: Colors.white,
                      ),
                    ),
                    if (meal.isStarterMeal)
                      Positioned(
                        top: 10,
                        left: 10,
                        child: _Pill(
                          label: 'أساسية',
                          bg: p.honeySolid,
                          fg: p.onSolid(p.honeySolid),
                          icon: AdminIcons.starter,
                        ),
                      ),
                  ],
                ),
              ),
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(14, 14, 14, 10),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        meal.name,
                        style: adminText(
                          size: 15,
                          weight: FontWeight.bold,
                          color: p.ink,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (meal.shortName != null &&
                          meal.shortName!.isNotEmpty) ...[
                        const SizedBox(height: 3),
                        Text(
                          'اختصار: ${meal.shortName}',
                          style: adminText(size: 11, color: p.inkFaint),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                      const SizedBox(height: 10),
                      Wrap(
                        spacing: 6,
                        runSpacing: 6,
                        children: [
                          _Pill(
                            label: _translateProtein(meal.proteinType),
                            bg: tint.bg,
                            fg: tint.fg,
                          ),
                          _Pill(
                            label: '${meal.prepTimeMinutes} د',
                            bg: p.honeySoft,
                            fg: p.honeyInk,
                            icon: AdminIcons.time,
                          ),
                          if (meal.isFridaySpecial)
                            _Pill(
                              label: 'جمعة',
                              bg: p.nileSoft,
                              fg: p.nileInk,
                              icon: AdminIcons.friday,
                            ),
                          if (!meal.isFridaySpecial)
                            _Pill(
                              label: _translateCarbs(meal.carbsType),
                              bg: catColor.withValues(alpha: 0.14),
                              fg: catColor,
                            ),
                        ],
                      ),
                      const Spacer(),
                      Row(
                        children: [
                          _RoundAction(
                            icon: AdminIcons.visibility,
                            fg: p.inkMuted,
                            bg: p.surfaceAlt,
                            tooltip: 'التفاصيل',
                            onPressed: onDetails,
                          ),
                          const Spacer(),
                          _RoundAction(
                            icon: AdminIcons.edit,
                            fg: p.clay,
                            bg: p.claySoft,
                            tooltip: 'تعديل',
                            onPressed: onEdit,
                          ),
                          const SizedBox(width: 8),
                          _RoundAction(
                            icon: AdminIcons.delete,
                            fg: p.chiliInk,
                            bg: p.chiliSoft,
                            tooltip: 'حذف',
                            onPressed: onDelete,
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _fallback(AdminPalette p) => Container(
    color: p.surfaceAlt,
    child: Center(
      child: Icon(AdminIcons.meal, color: p.borderStrong, size: 42),
    ),
  );
}

/// =============================== Suggestion row ===============================
class _SuggestionRow extends StatelessWidget {
  final CloudMeal meal;
  final VoidCallback? onApprove;
  final VoidCallback? onReject;
  final VoidCallback? onEdit;
  final VoidCallback onDetails;

  const _SuggestionRow({
    required this.meal,
    required this.onApprove,
    required this.onReject,
    required this.onEdit,
    required this.onDetails,
  });

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    final tint = p.proteinTint(meal.proteinType);
    final catColor = _categoryColor(meal.category, p);

    final image = ClipRRect(
      borderRadius: BorderRadius.circular(AdminRadii.md),
      child: SizedBox(
        width: 60,
        height: 60,
        child: meal.imageUrl != null && meal.imageUrl!.isNotEmpty
            ? Image.network(
                meal.imageUrl!,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _fallback(p),
              )
            : _fallback(p),
      ),
    );

    final info = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          meal.name,
          style: adminText(size: 14, weight: FontWeight.bold, color: p.ink),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        const SizedBox(height: 4),
        Row(
          children: [
            Icon(AdminIcons.person, size: 13, color: p.inkFaint),
            const SizedBox(width: 4),
            Expanded(
              child: Text(
                'بواسطة: ${meal.proposedBy ?? 'مجهول'}',
                style: adminText(size: 11, color: p.inkMuted),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ),
            const SizedBox(width: 8),
            Icon(AdminIcons.time, size: 13, color: p.inkFaint),
            const SizedBox(width: 4),
            Text(
              _formatDate(meal.createdAt),
              style: adminText(size: 11, color: p.inkFaint),
            ),
          ],
        ),
        const SizedBox(height: 10),
        Wrap(
          spacing: 6,
          runSpacing: 6,
          children: [
            _Pill(
              label: _translateProtein(meal.proteinType),
              bg: tint.bg,
              fg: tint.fg,
            ),
            _Pill(
              label: '${meal.prepTimeMinutes} د',
              bg: p.honeySoft,
              fg: p.honeyInk,
              icon: AdminIcons.time,
            ),
            _Pill(
              label: _translateCategory(meal.category),
              bg: catColor.withValues(alpha: 0.14),
              fg: catColor,
            ),
            _Pill(
              label: _translateCarbs(meal.carbsType),
              bg: p.surfaceSunken,
              fg: p.inkMuted,
            ),
          ],
        ),
        if (meal.notes != null && meal.notes!.isNotEmpty) ...[
          const SizedBox(height: 10),
          Text(
            meal.notes!,
            style: adminText(size: 11, color: p.inkFaint, height: 1.5),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        const SizedBox(height: 12),
        Row(
          children: [
            _RoundAction(
              icon: AdminIcons.visibility,
              fg: p.inkMuted,
              bg: p.surfaceAlt,
              tooltip: 'التفاصيل',
              onPressed: onDetails,
            ),
            const SizedBox(width: 8),
            _RoundAction(
              icon: AdminIcons.edit,
              fg: p.clay,
              bg: p.claySoft,
              tooltip: 'تعديل قبل الاعتماد',
              onPressed: onEdit,
            ),
            const Spacer(),
            OutlinedButton.icon(
              onPressed: onReject,
              icon: Icon(AdminIcons.close, size: 16, color: p.chiliInk),
              label: Text(
                'رفض',
                style: adminText(
                  size: 12,
                  weight: FontWeight.bold,
                  color: p.chiliInk,
                ),
              ),
              style: OutlinedButton.styleFrom(
                foregroundColor: p.chiliInk,
                padding: const EdgeInsets.symmetric(
                  horizontal: 14,
                  vertical: 12,
                ),
                side: BorderSide(color: p.chiliSolid.withValues(alpha: 0.5)),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AdminRadii.md),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FilledButton.icon(
              onPressed: onApprove,
              icon: const Icon(AdminIcons.check, size: 16),
              label: Text(
                'اعتماد',
                style: adminText(size: 12, weight: FontWeight.bold),
              ),
              style: FilledButton.styleFrom(
                backgroundColor: p.oliveSolid,
                foregroundColor: p.onSolid(p.oliveSolid),
                padding: const EdgeInsets.symmetric(
                  horizontal: 16,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(AdminRadii.md),
                ),
              ),
            ),
          ],
        ),
      ],
    );

    return Material(
      color: p.surface,
      borderRadius: BorderRadius.circular(AdminRadii.lg),
      clipBehavior: Clip.antiAlias,
      child: InkWell(
        onTap: onDetails,
        child: Container(
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AdminRadii.lg),
            border: Border.all(color: p.border),
          ),
          child: LayoutBuilder(
            builder: (context, c) {
              if (c.maxWidth < 720) {
                return Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Row(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        image,
                        const SizedBox(width: 14),
                        Expanded(child: info),
                      ],
                    ),
                  ],
                );
              }
              return Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  image,
                  const SizedBox(width: 16),
                  Expanded(child: info),
                ],
              );
            },
          ),
        ),
      ),
    );
  }

  Widget _fallback(AdminPalette p) => Container(
    color: p.surfaceAlt,
    child: Center(
      child: Icon(AdminIcons.meal, color: p.borderStrong, size: 24),
    ),
  );

  String _formatDate(DateTime d) {
    final now = DateTime.now();
    final isToday =
        d.year == now.year && d.month == now.month && d.day == now.day;
    final yesterday = now.subtract(const Duration(days: 1));
    final isYesterday =
        d.year == yesterday.year &&
        d.month == yesterday.month &&
        d.day == yesterday.day;

    final h = d.hour % 12 == 0 ? 12 : d.hour % 12;
    final period = d.hour >= 12 ? 'م' : 'ص';
    final time =
        '${h.toString().padLeft(2, '0')}:${d.minute.toString().padLeft(2, '0')} $period';

    if (isToday) return 'اليوم، $time';
    if (isYesterday) return 'أمس، $time';
    return '${d.day}/${d.month}/${d.year}';
  }
}

/// =============================== Building blocks ===============================
class _IconTile extends StatelessWidget {
  final IconData icon;
  final Color fg;
  final Color bg;

  const _IconTile({required this.icon, required this.fg, required this.bg});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 40,
      height: 40,
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AdminRadii.md),
      ),
      child: Icon(icon, color: fg, size: 20),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;
  final IconData? icon;

  const _Pill({
    required this.label,
    required this.bg,
    required this.fg,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AdminRadii.pill),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          if (icon != null) ...[
            Icon(icon, size: 12, color: fg),
            const SizedBox(width: 5),
          ],
          Text(
            label,
            style: adminText(size: 11, weight: FontWeight.w700, color: fg),
          ),
        ],
      ),
    );
  }
}

class _FilterChip extends StatelessWidget {
  final String label;
  final Color dotColor;
  final bool selected;
  final VoidCallback onTap;

  const _FilterChip({
    required this.label,
    required this.dotColor,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    return Material(
      color: selected ? p.claySoft : p.surfaceAlt,
      borderRadius: BorderRadius.circular(AdminRadii.pill),
      child: InkWell(
        borderRadius: BorderRadius.circular(AdminRadii.pill),
        onTap: onTap,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 9),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AdminRadii.pill),
            border: Border.all(
              color: selected ? p.clay.withValues(alpha: 0.55) : p.border,
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 7,
                height: 7,
                decoration: BoxDecoration(
                  color: dotColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: 7),
              Text(
                label,
                style: adminText(
                  size: 12,
                  weight: selected ? FontWeight.bold : FontWeight.w500,
                  color: selected ? p.onClaySoft : p.inkMuted,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _NoticeBanner extends StatelessWidget {
  final IconData icon;
  final String message;
  final Color bg;
  final Color fg;

  const _NoticeBanner({
    required this.icon,
    required this.message,
    required this.bg,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AdminRadii.md),
        border: Border.all(color: fg.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          Icon(icon, color: fg, size: 22),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              message,
              style: adminText(
                size: 13,
                weight: FontWeight.w600,
                color: fg,
                height: 1.6,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  final IconData icon;
  final String title;
  final String? message;
  final Color fg;

  const _EmptyState({
    required this.icon,
    required this.title,
    this.message,
    required this.fg,
  });

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 56),
      child: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Container(
              padding: const EdgeInsets.all(18),
              decoration: BoxDecoration(
                color: p.surfaceAlt,
                shape: BoxShape.circle,
              ),
              child: Icon(icon, size: 36, color: fg),
            ),
            const SizedBox(height: 16),
            Text(
              title,
              textAlign: TextAlign.center,
              style: adminText(size: 15, weight: FontWeight.bold, color: p.ink),
            ),
            if (message != null) ...[
              const SizedBox(height: 6),
              ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 360),
                child: Text(
                  message!,
                  textAlign: TextAlign.center,
                  style: adminText(size: 12, color: p.inkMuted, height: 1.6),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}

class _RoundAction extends StatelessWidget {
  final IconData icon;
  final Color fg;
  final Color bg;
  final String tooltip;
  final VoidCallback? onPressed;

  const _RoundAction({
    required this.icon,
    required this.fg,
    required this.bg,
    required this.tooltip,
    this.onPressed,
  });

  @override
  Widget build(BuildContext context) {
    return Tooltip(
      message: tooltip,
      child: Material(
        color: bg,
        borderRadius: BorderRadius.circular(AdminRadii.sm),
        child: InkWell(
          borderRadius: BorderRadius.circular(AdminRadii.sm),
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(8),
            child: Icon(
              icon,
              size: 18,
              color: onPressed == null ? fg.withValues(alpha: 0.35) : fg,
            ),
          ),
        ),
      ),
    );
  }
}

// ─────────────────────────────────────────────────────────────────────────────
// Settings-page helper widgets
// ─────────────────────────────────────────────────────────────────────────────

class _SettingsSectionLabel extends StatelessWidget {
  final String label;
  final AdminPalette palette;
  const _SettingsSectionLabel({required this.label, required this.palette});

  @override
  Widget build(BuildContext context) {
    final p = palette;
    return Row(
      children: [
        Text(
          label,
          style: adminText(
            size: 11,
            weight: FontWeight.w700,
            color: p.inkFaint,
          ),
        ),
        const SizedBox(width: 10),
        Expanded(child: Divider(height: 1, color: p.border)),
      ],
    );
  }
}

class _SettingsDivider extends StatelessWidget {
  final AdminPalette p;
  const _SettingsDivider({required this.p});

  @override
  Widget build(BuildContext context) {
    return Divider(height: 1, indent: 60, endIndent: 0, color: p.border);
  }
}

class _SettingsChevronButton extends StatelessWidget {
  final String label;
  final Color color;
  final Color bg;
  final bool enabled;
  final VoidCallback onTap;

  const _SettingsChevronButton({
    required this.label,
    required this.color,
    required this.bg,
    required this.enabled,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: enabled ? onTap : null,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
        decoration: BoxDecoration(
          color: enabled ? bg : bg.withValues(alpha: 0.4),
          borderRadius: BorderRadius.circular(AdminRadii.md),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              label,
              style: adminText(
                size: 12,
                weight: FontWeight.bold,
                color: enabled ? color : color.withValues(alpha: 0.4),
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              AdminIcons.chevronStart,
              size: 16,
              color: enabled ? color : color.withValues(alpha: 0.4),
            ),
          ],
        ),
      ),
    );
  }
}
