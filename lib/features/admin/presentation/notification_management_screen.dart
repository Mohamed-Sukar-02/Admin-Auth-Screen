import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../data/models/ai_notification_result.dart';
import '../data/models/cloud_meal.dart';
import '../data/vault_admin_repository.dart';
import 'theme/admin_palette.dart';
import 'widgets/admin_dialog.dart';
import 'widgets/ai_assistant_panel.dart';

/// A broadcast template: one type glyph, one label, one tint pair.
typedef _NotificationType = ({String key, String label, IconData icon});

/// A deep-link destination: the label the admin taps, and the route the mobile
/// app opens. [route] is empty for the presets resolved at send time
/// (a specific vault meal, or whatever the admin typed for a custom link).
typedef _DestinationPreset = ({
  String key,
  String label,
  String route,
  IconData icon,
});

/// ===========================================================================
/// Notification management
///
/// Broadcasts a bilingual notification to every app user and keeps the history
/// of what was sent. The write path lives in [VaultAdminRepository]; this
/// screen only composes the payload and renders the stream.
/// ===========================================================================
class NotificationManagementScreen extends ConsumerStatefulWidget {
  const NotificationManagementScreen({super.key});

  @override
  ConsumerState<NotificationManagementScreen> createState() =>
      _NotificationManagementScreenState();
}

class _NotificationManagementScreenState
    extends ConsumerState<NotificationManagementScreen> {
  static const List<_NotificationType> _types = [
    (key: 'meal', label: 'وجبة / اقتراح', icon: Icons.restaurant_menu_rounded),
    (key: 'reminder', label: 'تذكير', icon: Icons.alarm_rounded),
    (key: 'update', label: 'تحديث', icon: Icons.system_update_alt_rounded),
  ];

  static const List<_DestinationPreset> _destinations = [
    (
      key: 'home',
      label: 'الصفحة الرئيسية',
      route: '/',
      icon: Icons.home_rounded,
    ),
    (
      key: 'meal',
      label: 'وجبة محددة من الخزنة',
      route: '',
      icon: AdminIcons.meal,
    ),
    (
      key: 'vault',
      label: 'خزانة الأكلات',
      route: '/vault',
      icon: Icons.inventory_2_rounded,
    ),
    (
      key: 'explore',
      label: 'استكشاف الأكلات السحابية',
      route: '/vault?tab=explore',
      icon: Icons.travel_explore_rounded,
    ),
    (
      key: 'settings',
      label: 'إعدادات التطبيق',
      route: '/settings',
      icon: Icons.settings_rounded,
    ),
    (key: 'custom', label: 'رابط مخصص', route: '', icon: AdminIcons.link),
  ];

  final _formKey = GlobalKey<FormState>();
  final _titleArController = TextEditingController();
  final _titleEnController = TextEditingController();
  final _messageArController = TextEditingController();
  final _messageEnController = TextEditingController();
  final _customRouteController = TextEditingController();

  String _selectedType = 'meal';
  String _selectedDestination = 'home';
  String? _selectedMealId;
  bool _isSending = false;

  @override
  void dispose() {
    _titleArController.dispose();
    _titleEnController.dispose();
    _messageArController.dispose();
    _messageEnController.dispose();
    _customRouteController.dispose();
    super.dispose();
  }

  /// The route this notification will carry, or empty when the destination
  /// still needs a value the admin has not supplied yet.
  ///
  /// A picked meal is re-checked against `meals` so a vault document deleted
  /// mid-compose can never send a stale id.
  String _resolveRoute(List<CloudMeal> meals) {
    switch (_selectedDestination) {
      case 'meal':
        final id = _selectedMealId;
        if (id == null || !meals.any((meal) => meal.id == id)) return '';
        return '/meal/cloud/$id';
      case 'custom':
        return _customRouteController.text.trim();
      default:
        return _destinations
            .firstWhere((d) => d.key == _selectedDestination)
            .route;
    }
  }

  /// ---------------------------------------------------------------- send ---
  Future<void> _sendNotification() async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final meals = _selectedDestination == 'meal'
        ? (ref.read(vaultMealsStreamProvider).valueOrNull ??
              const <CloudMeal>[])
        : const <CloudMeal>[];
    final targetRoute = _resolveRoute(meals);
    if (targetRoute.isEmpty) {
      // Reachable when the vault stream is still loading on a `meal` target,
      // where no field exists yet to fail form validation.
      _showSnack(
        'أكمل وجهة التوجيه قبل الإرسال',
        AdminPalette.of(context).honeySolid,
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isSending = true);

    try {
      await ref
          .read(vaultAdminRepositoryProvider)
          .sendNotification(
            type: _selectedType,
            titleAr: _titleArController.text.trim(),
            titleEn: _titleEnController.text.trim(),
            messageAr: _messageArController.text.trim(),
            messageEn: _messageEnController.text.trim(),
            sentBy: FirebaseAuth.instance.currentUser?.email ?? 'admin',
            route: targetRoute,
          );

      _titleArController.clear();
      _titleEnController.clear();
      _messageArController.clear();
      _messageEnController.clear();
      _customRouteController.clear();
      if (mounted) setState(() => _selectedMealId = null);
      _reportSuccess();
    } catch (error) {
      _reportFailure(error);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _showSnack(String message, Color background) {
    ScaffoldMessenger.of(context)
      ..hideCurrentSnackBar()
      ..showSnackBar(
        SnackBar(
          content: Text(message, style: adminText(color: Colors.white)),
          backgroundColor: background,
          behavior: SnackBarBehavior.floating,
        ),
      );
  }

  void _reportSuccess() {
    if (!mounted) return;
    _showSnack('تم إرسال الإشعار بنجاح', AdminPalette.of(context).oliveSolid);
  }

  void _reportFailure(Object error) {
    if (!mounted) return;
    _showSnack(
      'فشل إرسال الإشعار: $error',
      AdminPalette.of(context).chiliSolid,
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> notification) async {
    final p = AdminPalette.of(context);
    final title = (notification['titleAr'] as String? ?? '').trim();

    final confirmed = await showAdminConfirmDialog(
      context: context,
      icon: AdminIcons.delete,
      tone: AdminDialogTone.danger,
      title: 'حذف هذا الإشعار؟',
      subtitle: title.isEmpty ? null : title,
      message: 'سيختفي الإشعار من السجل ولن يظهر للمستخدمين بعد الآن.',
      confirmLabel: 'حذف',
      confirmIcon: AdminIcons.delete,
    );
    if (!confirmed || !mounted) return;

    final id = notification['id'] as String?;
    if (id == null) return;

    try {
      await ref.read(vaultAdminRepositoryProvider).deleteNotification(id);
    } catch (error) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(
            content: Text(
              'تعذّر حذف الإشعار: $error',
              style: adminText(color: Colors.white),
            ),
            backgroundColor: p.chiliSolid,
            behavior: SnackBarBehavior.floating,
          ),
        );
    }
  }

  /// Pushes an AI-generated draft into the compose form. The type key is
  /// already one of [_types], so the chip row picks it up without remapping.
  void _applyAiResult(AiNotificationResult result) {
    setState(() {
      _titleArController.text = result.titleAr;
      _titleEnController.text = result.titleEn;
      _messageArController.text = result.messageAr;
      _messageEnController.text = result.messageEn;
      _selectedType = result.type;
    });
    _showSnack(
      'تم ملء بيانات الإشعار من المساعد الذكي',
      AdminPalette.of(context).oliveSolid,
    );
  }

  /// -------------------------------------------------------------- layout ---
  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    final isWide = MediaQuery.sizeOf(context).width >= 1150;

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 20, 26, 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1380),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _buildHeader(p),
            const SizedBox(height: 28),
            _SectionLabel(label: 'إنشاء إشعار جديد', palette: p),
            const SizedBox(height: 10),

            if (isWide)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(flex: 5, child: _buildComposeCard(p)),
                  const SizedBox(width: 20),
                  Expanded(
                    flex: 4,
                    child: AiAssistantPanel(onApplyToForm: _applyAiResult),
                  ),
                ],
              )
            else ...[
              _buildComposeCard(p),
              const SizedBox(height: 20),
              AiAssistantPanel(onApplyToForm: _applyAiResult),
            ],

            const SizedBox(height: 28),
            _SectionLabel(label: 'سجل الإشعارات المرسلة', palette: p),
            const SizedBox(height: 10),
            _buildHistory(p),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(AdminPalette p) {
    return Row(
      children: [
        Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: p.claySoft,
            borderRadius: BorderRadius.circular(AdminRadii.md),
          ),
          child: Icon(AdminIcons.campaign, size: 22, color: p.claySolid),
        ),
        const SizedBox(width: 14),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'إدارة الإشعارات',
              style: adminText(size: 20, weight: FontWeight.bold, color: p.ink),
            ),
            Text(
              'إرسال إشعارات عامة لجميع مستخدمي التطبيق',
              style: adminText(size: 12, color: p.inkMuted),
            ),
          ],
        ),
      ],
    );
  }

  Widget _buildComposeCard(AdminPalette p) {
    // The vault stream is only listened to while a specific meal is the target,
    // so composing any other notification costs no vault reads.
    final pickingMeal = _selectedDestination == 'meal';
    final mealsAsync = pickingMeal ? ref.watch(vaultMealsStreamProvider) : null;
    final meals = mealsAsync?.valueOrNull ?? const <CloudMeal>[];

    return Container(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 20),
      decoration: p.panel(shadow: true),
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Text(
              'نوع الإشعار',
              style: adminText(
                size: 12.5,
                weight: FontWeight.w700,
                color: p.inkMuted,
              ),
            ),
            const SizedBox(height: 10),
            _buildChoiceChips(
              options: _types,
              selected: _selectedType,
              onSelect: (key) => setState(() => _selectedType = key),
            ),
            const SizedBox(height: 20),
            _buildField(
              controller: _titleArController,
              label: 'العنوان بالعربي',
              icon: AdminIcons.basicInfo,
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _titleEnController,
              label: 'العنوان بالإنجليزي',
              icon: AdminIcons.basicInfo,
              ltr: true,
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _messageArController,
              label: 'الرسالة بالعربي',
              icon: AdminIcons.notes,
              maxLines: 3,
            ),
            const SizedBox(height: 12),
            _buildField(
              controller: _messageEnController,
              label: 'الرسالة بالإنجليزي',
              icon: AdminIcons.notes,
              maxLines: 3,
              ltr: true,
            ),
            const SizedBox(height: 20),
            Text(
              'وجهة التوجيه عند الضغط',
              style: adminText(
                size: 12.5,
                weight: FontWeight.w700,
                color: p.inkMuted,
              ),
            ),
            const SizedBox(height: 10),
            _buildChoiceChips(
              options: _destinations
                  .map((d) => (key: d.key, label: d.label, icon: d.icon))
                  .toList(),
              selected: _selectedDestination,
              onSelect: (key) => setState(() {
                _selectedDestination = key;
                if (key != 'meal') _selectedMealId = null;
              }),
            ),
            if (pickingMeal) ...[
              const SizedBox(height: 12),
              _buildMealTarget(p, mealsAsync!),
            ],
            if (_selectedDestination == 'custom') ...[
              const SizedBox(height: 12),
              _buildField(
                controller: _customRouteController,
                label: 'رابط مخصص',
                hint: '/promo/ramadan',
                icon: AdminIcons.link,
                ltr: true,
                validator: _validateCustomRoute,
              ),
            ],
            const SizedBox(height: 14),
            _buildRoutePreview(p, _resolveRoute(meals)),
            const SizedBox(height: 20),
            _buildSendButton(p),
          ],
        ),
      ),
    );
  }

  /// The two option rows (broadcast type, deep-link destination) share one
  /// chip treatment; only the tint of the selected chip differs from the rest.
  Widget _buildChoiceChips({
    required List<({String key, String label, IconData icon})> options,
    required String selected,
    required ValueChanged<String> onSelect,
  }) {
    final p = AdminPalette.of(context);
    return Wrap(
      spacing: 10,
      runSpacing: 10,
      children: [
        for (final option in options)
          ChoiceChip(
            selected: selected == option.key,
            onSelected: (_) => onSelect(option.key),
            avatar: Icon(
              option.icon,
              size: 18,
              color: selected == option.key ? p.onClaySoft : p.inkMuted,
            ),
            label: Text(
              option.label,
              style: adminText(
                size: 13,
                weight: FontWeight.w600,
                color: selected == option.key ? p.onClaySoft : p.inkMuted,
              ),
            ),
            backgroundColor: p.surfaceAlt,
            selectedColor: p.claySoft,
            side: BorderSide(color: selected == option.key ? p.clay : p.border),
            showCheckmark: false,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
          ),
      ],
    );
  }

  /// Vault picker for the `meal` destination. A deleted document drops the
  /// selection back to null, which the field's validator then reports.
  Widget _buildMealTarget(
    AdminPalette p,
    AsyncValue<List<CloudMeal>> mealsAsync,
  ) {
    return mealsAsync.when(
      loading: () => _TargetHint(
        icon: AdminIcons.time,
        text: 'جارٍ تحميل أكلات الخزنة…',
        palette: p,
      ),
      error: (error, _) => _TargetHint(
        icon: AdminIcons.warning,
        text: 'تعذّر تحميل أكلات الخزنة: $error',
        palette: p,
        isError: true,
      ),
      data: (meals) {
        if (meals.isEmpty) {
          return _TargetHint(
            icon: AdminIcons.empty,
            text: 'خزنة الأكلات فارغة الآن؛ اختر وجهة أخرى أو ارفع أكلة أولاً.',
            palette: p,
          );
        }

        final selected = meals.any((meal) => meal.id == _selectedMealId)
            ? _selectedMealId
            : null;

        return DropdownButtonFormField<String>(
          initialValue: selected,
          isExpanded: true,
          dropdownColor: p.surface,
          borderRadius: BorderRadius.circular(AdminRadii.md),
          icon: Icon(AdminIcons.expand, color: p.inkMuted),
          style: adminText(color: p.ink),
          decoration: adminFieldDeco(
            p,
            label: 'اختر الأكلة من الخزنة',
            icon: AdminIcons.meal,
            helper: 'تُفتح صفحة الأكلة المختارة عند الضغط على الإشعار',
          ),
          items: [
            for (final meal in meals)
              DropdownMenuItem<String>(
                value: meal.id,
                child: Text(
                  meal.name.isEmpty ? meal.id : meal.name,
                  overflow: TextOverflow.ellipsis,
                  style: adminText(size: 14, color: p.ink),
                ),
              ),
          ],
          onChanged: (value) => setState(() => _selectedMealId = value),
          validator: (value) => (value == null || value.isEmpty)
              ? 'اختر الأكلة التي سيفتحها الإشعار'
              : null,
        );
      },
    );
  }

  String? _validateCustomRoute(String? value) {
    final route = value?.trim() ?? '';
    if (route.isEmpty) return 'هذا الحقل مطلوب';
    if (!route.startsWith('/')) return 'يجب أن يبدأ المسار بشرطة مائلة';
    return null;
  }

  /// Exactly what the mobile app will receive, so nothing ships blind.
  Widget _buildRoutePreview(AdminPalette p, String route) {
    if (route.isEmpty) {
      return _TargetHint(
        icon: AdminIcons.link,
        text: 'لم تُحدَّد وجهة التوجيه بعد — أكملها قبل الإرسال.',
        palette: p,
      );
    }

    return Row(
      children: [
        Text(
          'المسار النهائي',
          style: adminText(
            size: 11.5,
            weight: FontWeight.w700,
            color: p.inkFaint,
          ),
        ),
        const SizedBox(width: 10),
        Flexible(child: _RoutePill(route: route)),
      ],
    );
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    required IconData icon,
    int maxLines = 1,
    bool ltr = false,
    String? hint,
    String? Function(String?)? validator,
  }) {
    final p = AdminPalette.of(context);
    return TextFormField(
      controller: controller,
      maxLines: maxLines,
      autovalidateMode: AutovalidateMode.onUserInteraction,
      style: adminText(color: p.ink, height: 1.6),
      textDirection: ltr ? TextDirection.ltr : null,
      validator:
          validator ??
          (value) => (value == null || value.trim().isEmpty)
              ? 'هذا الحقل مطلوب'
              : null,
      decoration: adminFieldDeco(p, label: label, icon: icon, hint: hint),
    );
  }

  Widget _buildSendButton(AdminPalette p) {
    return FilledButton(
      onPressed: _isSending ? null : _sendNotification,
      style: FilledButton.styleFrom(
        backgroundColor: p.claySolid,
        foregroundColor: Colors.white,
        disabledBackgroundColor: p.claySolid.withValues(alpha: 0.6),
        disabledForegroundColor: Colors.white70,
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 17),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminRadii.md),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isSending)
            const SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: Colors.white,
              ),
            )
          else
            const Icon(AdminIcons.campaign, size: 19, color: Colors.white),
          const SizedBox(width: 10),
          Text(
            _isSending ? 'جارٍ الإرسال…' : 'إرسال الإشعار لجميع المستخدمين',
            style: adminText(size: 14.5, weight: FontWeight.bold),
          ),
        ],
      ),
    );
  }

  Widget _buildHistory(AdminPalette p) {
    final notificationsAsync = ref.watch(adminNotificationsStreamProvider);

    return notificationsAsync.when(
      loading: () => Container(
        padding: const EdgeInsets.symmetric(vertical: 46),
        decoration: p.panel(),
        child: Center(
          child: SizedBox(
            width: 26,
            height: 26,
            child: CircularProgressIndicator(
              strokeWidth: 2.6,
              color: p.claySolid,
            ),
          ),
        ),
      ),
      error: (error, _) => Container(
        padding: const EdgeInsets.all(22),
        decoration: p.panel(borderColor: p.chiliSolid.withValues(alpha: 0.4)),
        child: Row(
          children: [
            Icon(AdminIcons.warning, size: 20, color: p.chiliInk),
            const SizedBox(width: 12),
            Expanded(
              child: Text(
                'تعذّر تحميل سجل الإشعارات: $error',
                style: adminText(size: 13, color: p.chiliInk, height: 1.6),
              ),
            ),
          ],
        ),
      ),
      data: (notifications) {
        if (notifications.isEmpty) {
          return Container(
            padding: const EdgeInsets.symmetric(vertical: 52, horizontal: 24),
            decoration: p.panel(),
            child: Column(
              children: [
                Container(
                  width: 62,
                  height: 62,
                  decoration: BoxDecoration(
                    color: p.surfaceSunken,
                    borderRadius: BorderRadius.circular(AdminRadii.pill),
                  ),
                  child: Icon(AdminIcons.empty, size: 28, color: p.inkFaint),
                ),
                const SizedBox(height: 16),
                Text(
                  'لم يتم إرسال أي إشعارات بعد',
                  style: adminText(
                    size: 15,
                    weight: FontWeight.bold,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'أول إشعار ترسله سيظهر هنا مع تاريخ الإرسال ومن أرسله.',
                  style: adminText(size: 12.5, color: p.inkMuted, height: 1.6),
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          );
        }

        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            for (final notification in notifications)
              Padding(
                padding: const EdgeInsets.only(bottom: 12),
                child: _NotificationCard(
                  notification: notification,
                  onDelete: () => _confirmDelete(notification),
                ),
              ),
          ],
        );
      },
    );
  }
}

/// ===========================================================================
/// Compose card helpers
/// ===========================================================================
class _SectionLabel extends StatelessWidget {
  final String label;
  final AdminPalette palette;

  const _SectionLabel({required this.label, required this.palette});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 4,
          height: 16,
          decoration: BoxDecoration(
            color: palette.claySolid,
            borderRadius: BorderRadius.circular(2),
          ),
        ),
        const SizedBox(width: 10),
        Text(
          label,
          style: adminText(
            size: 13,
            weight: FontWeight.w700,
            color: palette.inkMuted,
          ),
        ),
      ],
    );
  }
}

/// Neutral placeholder for a destination that has no value to show yet: the
/// vault picker while its stream is loading, failed or empty, and the route
/// preview while the admin has not finished choosing.
class _TargetHint extends StatelessWidget {
  final IconData icon;
  final String text;
  final AdminPalette palette;
  final bool isError;

  const _TargetHint({
    required this.icon,
    required this.text,
    required this.palette,
    this.isError = false,
  });

  @override
  Widget build(BuildContext context) {
    final fg = isError ? palette.chiliInk : palette.inkMuted;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      decoration: BoxDecoration(
        color: isError ? palette.chiliSoft : palette.surfaceAlt,
        borderRadius: BorderRadius.circular(AdminRadii.sm),
        border: Border.all(
          color: isError
              ? palette.chiliSolid.withValues(alpha: 0.35)
              : palette.border,
        ),
      ),
      child: Row(
        children: [
          Icon(icon, size: 17, color: fg),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: adminText(size: 12.5, color: fg, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}

/// One broadcast in the history list.
class _NotificationCard extends StatelessWidget {
  final Map<String, dynamic> notification;
  final VoidCallback onDelete;

  const _NotificationCard({required this.notification, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    final type = _typeStyle(p, notification['type'] as String?);
    final titleAr = (notification['titleAr'] as String? ?? '').trim();
    final titleEn = (notification['titleEn'] as String? ?? '').trim();
    final messageAr = (notification['messageAr'] as String? ?? '').trim();
    final messageEn = (notification['messageEn'] as String? ?? '').trim();
    final sentBy = (notification['sentBy'] as String? ?? 'admin').trim();
    // Notifications composed before deep links existed carry no field at all,
    // and the app treats a missing route as the home screen.
    final storedRoute = (notification['route'] as String? ?? '').trim();
    final route = storedRoute.isEmpty ? '/' : storedRoute;

    return Container(
      padding: const EdgeInsets.fromLTRB(16, 16, 12, 14),
      decoration: p.panel(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: type.bg,
                  borderRadius: BorderRadius.circular(AdminRadii.md),
                ),
                child: Icon(type.icon, size: 20, color: type.fg),
              ),
              const SizedBox(width: 13),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Expanded(
                          child: Text(
                            titleAr.isEmpty ? 'بدون عنوان' : titleAr,
                            style: adminText(
                              size: 15,
                              weight: FontWeight.bold,
                              color: p.ink,
                              height: 1.45,
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        _TypePill(label: type.label, bg: type.bg, fg: type.fg),
                      ],
                    ),
                    if (titleEn.isNotEmpty) ...[
                      const SizedBox(height: 3),
                      Text(
                        titleEn,
                        textDirection: TextDirection.ltr,
                        style: adminText(size: 12.5, color: p.inkMuted),
                      ),
                    ],
                  ],
                ),
              ),
              IconButton(
                onPressed: onDelete,
                tooltip: 'حذف',
                visualDensity: VisualDensity.compact,
                icon: Icon(AdminIcons.delete, size: 18, color: p.inkFaint),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (messageAr.isNotEmpty)
            Text(
              messageAr,
              style: adminText(size: 13.5, color: p.ink, height: 1.7),
            ),
          if (messageEn.isNotEmpty) ...[
            const SizedBox(height: 4),
            Text(
              messageEn,
              textDirection: TextDirection.ltr,
              style: adminText(size: 12.5, color: p.inkMuted, height: 1.6),
            ),
          ],
          const SizedBox(height: 12),
          _RoutePill(route: route),
          const SizedBox(height: 12),
          Container(height: 1, color: p.border),
          const SizedBox(height: 10),
          Row(
            children: [
              Icon(AdminIcons.time, size: 14, color: p.inkFaint),
              const SizedBox(width: 6),
              Text(
                _formatSentAt(notification['sentAt']),
                style: adminText(size: 11.5, color: p.inkMuted),
              ),
              const SizedBox(width: 14),
              Icon(AdminIcons.person, size: 14, color: p.inkFaint),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  sentBy,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  style: adminText(size: 11.5, color: p.inkMuted),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _TypePill extends StatelessWidget {
  final String label;
  final Color bg;
  final Color fg;

  const _TypePill({required this.label, required this.bg, required this.fg});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AdminRadii.pill),
      ),
      child: Text(
        label,
        style: adminText(size: 11, weight: FontWeight.w700, color: fg),
      ),
    );
  }
}

/// Where this broadcast takes the user. A path, not Arabic prose, so it stays
/// LTR and a leading slash never mirrors to the wrong side.
class _RoutePill extends StatelessWidget {
  final String route;

  const _RoutePill({required this.route});

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      constraints: const BoxConstraints(maxWidth: 420),
      decoration: BoxDecoration(
        color: p.nileSoft,
        borderRadius: BorderRadius.circular(AdminRadii.pill),
        border: Border.all(color: p.nileSolid.withValues(alpha: 0.28)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(AdminIcons.link, size: 13, color: p.nileInk),
          const SizedBox(width: 6),
          Flexible(
            child: Text(
              route,
              overflow: TextOverflow.ellipsis,
              textDirection: TextDirection.ltr,
              style: adminText(
                size: 11,
                weight: FontWeight.w700,
                color: p.nileInk,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// ===========================================================================
/// Type + date mapping
/// ===========================================================================
/// Broadcast kinds are stored as free strings, so an unknown value falls back
/// to the meal tint instead of painting a colourless badge.
({Color bg, Color fg, IconData icon, String label}) _typeStyle(
  AdminPalette p,
  String? type,
) {
  switch (type) {
    case 'reminder':
      return (
        bg: p.nileSoft,
        fg: p.nileInk,
        icon: Icons.alarm_rounded,
        label: 'تذكير',
      );
    case 'update':
      return (
        bg: p.oliveSoft,
        fg: p.oliveInk,
        icon: Icons.system_update_alt_rounded,
        label: 'تحديث',
      );
    default:
      return (
        bg: p.honeySoft,
        fg: p.honeyInk,
        icon: Icons.restaurant_menu_rounded,
        label: 'وجبة',
      );
  }
}

const List<String> _arabicMonths = [
  'يناير',
  'فبراير',
  'مارس',
  'أبريل',
  'مايو',
  'يونيو',
  'يوليو',
  'أغسطس',
  'سبتمبر',
  'أكتوبر',
  'نوفمبر',
  'ديسمبر',
];

/// [sentAt] is a server timestamp, so a write still in flight reads as null.
String _formatSentAt(Object? sentAt) {
  if (sentAt is! Timestamp) return 'جارٍ الإرسال…';
  final date = sentAt.toDate();
  final hour24 = date.hour;
  final hour12 = hour24 % 12 == 0 ? 12 : hour24 % 12;
  final minute = date.minute.toString().padLeft(2, '0');
  final period = hour24 < 12 ? 'صباحاً' : 'مساءً';
  return '${date.day} ${_arabicMonths[date.month - 1]} ${date.year} • '
      '$hour12:$minute $period';
}
