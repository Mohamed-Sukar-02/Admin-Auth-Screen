import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/localization/app_strings.dart';
import '../data/models/ai_notification_result.dart';
import '../data/models/cloud_meal.dart';
import '../data/vault_admin_repository.dart';
import 'theme/admin_palette.dart';
import 'widgets/admin_dialog.dart';
import 'widgets/admin_toast.dart';
import 'widgets/ai_assistant_panel.dart';
import 'widgets/notification_review.dart';

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
    (key: 'meal', label: 'وجبة / اقتراح', icon: AdminIcons.meal),
    (key: 'reminder', label: 'تذكير', icon: AdminIcons.reminder),
    (key: 'update', label: 'تحديث', icon: AdminIcons.update),
  ];

  static const List<_DestinationPreset> _destinations = [
    (key: 'home', label: 'الصفحة الرئيسية', route: '/', icon: AdminIcons.home),
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
      icon: AdminIcons.vault,
    ),
    (
      key: 'explore',
      label: 'استكشاف الأكلات السحابية',
      route: '/vault?tab=explore',
      icon: AdminIcons.explore,
    ),
    (
      key: 'settings',
      label: 'إعدادات التطبيق',
      route: '/settings',
      icon: AdminIcons.settings,
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

  /// 0 = إشعار جديد, 1 = سجل الإشعارات, 2 = المسودات
  int _tab = 0;

  /// Set while the compose form is editing a saved draft, so saving again
  /// overwrites that draft instead of piling up copies of it.
  String? _editingDraftId;
  bool _savingDraft = false;

  /// Drives the card's status chip: an applied assistant draft reads differently
  /// from copy the admin typed themselves.
  bool _draftFromAssistant = false;

  @override
  void initState() {
    super.initState();
    for (final controller in _copyControllers) {
      controller.addListener(_clearAssistantFlag);
    }
  }

  @override
  void dispose() {
    for (final controller in _copyControllers) {
      controller.removeListener(_clearAssistantFlag);
      controller.dispose();
    }
    _customRouteController.dispose();
    super.dispose();
  }

  List<TextEditingController> get _copyControllers => [
    _titleArController,
    _titleEnController,
    _messageArController,
    _messageEnController,
  ];

  void _clearAssistantFlag() {
    if (_draftFromAssistant) setState(() => _draftFromAssistant = false);
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
      showAdminToast(
        context,
        message: 'أكمل وجهة التوجيه قبل الإرسال',
        kind: AdminToastKind.warning,
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
      // A draft that just went out is no longer a draft.
      final sentDraftId = _editingDraftId;
      if (sentDraftId != null) {
        await ref.read(vaultAdminRepositoryProvider).deleteDraft(sentDraftId);
      }
      if (mounted) {
        setState(() {
          _selectedMealId = null;
          _editingDraftId = null;
          _draftFromAssistant = false;
        });
      }
      _reportSuccess();
    } catch (error) {
      _reportFailure(error);
    } finally {
      if (mounted) setState(() => _isSending = false);
    }
  }

  void _reportSuccess() {
    if (!mounted) return;
    showAdminToast(
      context,
      message: 'تم إرسال الإشعار بنجاح',
      kind: AdminToastKind.success,
    );
  }

  void _reportFailure(Object error) {
    if (!mounted) return;
    showAdminToast(
      context,
      message: 'فشل إرسال الإشعار',
      subtitle: error.toString(),
      kind: AdminToastKind.error,
    );
  }

  Future<void> _confirmDelete(Map<String, dynamic> notification) async {
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
      showAdminToast(
        context,
        message: 'تعذّر حذف الإشعار',
        subtitle: error.toString(),
        kind: AdminToastKind.error,
      );
    }
  }

  /// Pushes an AI-generated draft into the compose form. The type key is
  /// already one of [_types], so the chip row picks it up without remapping.
  ///
  /// Copy the admin already typed is never silently overwritten: the swap is
  /// confirmed first, and the answer tells the assistant whether to latch its
  /// button. Only the four texts and the type move — the destination stays.
  Future<bool> _applyAiResult(AiNotificationResult result) async {
    final strings = AppStrings.of(context);
    final hasTypedCopy =
        _titleArController.text.trim().isNotEmpty ||
        _messageArController.text.trim().isNotEmpty;

    if (hasTypedCopy) {
      final replaced = await showAdminConfirmDialog(
        context: context,
        icon: AdminIcons.aiSparkle,
        tone: AdminDialogTone.warn,
        title: strings.aiReplaceConfirmTitle,
        message: strings.aiReplaceConfirmBody,
        confirmLabel: strings.aiUseSuggestion,
        cancelLabel: strings.aiKeepCurrent,
        confirmIcon: AdminIcons.check,
      );
      if (!replaced || !mounted) return false;
    }

    setState(() {
      _titleArController.text = result.titleAr;
      _titleEnController.text = result.titleEn;
      _messageArController.text = result.messageAr;
      _messageEnController.text = result.messageEn;
      _selectedType = result.type;
      _draftFromAssistant = true;
    });
    showAdminToast(
      context,
      message: strings.aiAppliedSuccess,
      kind: AdminToastKind.success,
    );
    return true;
  }

  /// ---------------------------------------------------------------- drafts ---
  /// Saves the compose form into `admin_notification_drafts`. The destination
  /// and picked meal travel with the copy, so reopening a draft resumes the
  /// whole broadcast rather than just its text.
  Future<void> _saveDraft() async {
    final titleAr = _titleArController.text.trim();
    final messageAr = _messageArController.text.trim();
    if (titleAr.isEmpty && messageAr.isEmpty) {
      showAdminToast(
        context,
        message: 'مفيش حاجة تتحفظ',
        subtitle: 'اكتب عنوان الإشعار أو رسائله الأول.',
        kind: AdminToastKind.warning,
      );
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _savingDraft = true);

    try {
      final id = await ref
          .read(vaultAdminRepositoryProvider)
          .saveDraft(
            id: _editingDraftId,
            type: _selectedType,
            titleAr: titleAr,
            titleEn: _titleEnController.text.trim(),
            messageAr: messageAr,
            messageEn: _messageEnController.text.trim(),
            savedBy: FirebaseAuth.instance.currentUser?.email ?? 'admin',
            route: _resolveRoute(const <CloudMeal>[]),
          );
      if (!mounted) return;
      setState(() => _editingDraftId = id);
      showAdminToast(
        context,
        message: 'تم حفظ المسودة',
        kind: AdminToastKind.success,
      );
    } catch (error) {
      if (!mounted) return;
      showAdminToast(
        context,
        message: 'تعذّر حفظ المسودة',
        subtitle: error.toString(),
        kind: AdminToastKind.error,
      );
    } finally {
      if (mounted) setState(() => _savingDraft = false);
    }
  }

  void _openDraft(Map<String, dynamic> draft) {
    setState(() {
      _tab = 0;
      _editingDraftId = draft['id'] as String?;
      _draftFromAssistant = false;
      _titleArController.text = draft['titleAr'] as String? ?? '';
      _titleEnController.text = draft['titleEn'] as String? ?? '';
      _messageArController.text = draft['messageAr'] as String? ?? '';
      _messageEnController.text = draft['messageEn'] as String? ?? '';
      _selectedType = draft['type'] as String? ?? 'meal';
    });
  }

  Future<void> _confirmDeleteDraft(Map<String, dynamic> draft) async {
    final id = draft['id'] as String?;
    if (id == null) return;
    final title = (draft['titleAr'] as String? ?? '').trim();

    final confirmed = await showAdminConfirmDialog(
      context: context,
      icon: AdminIcons.delete,
      tone: AdminDialogTone.warn,
      title: 'حذف هذه المسودة؟',
      subtitle: title.isEmpty ? null : title,
      message: 'المسودة لسه ما اتبعتتش، وحذفها يشيلها من كل الأجهزة.',
      confirmLabel: 'حذف',
      confirmIcon: AdminIcons.delete,
    );
    if (!confirmed || !mounted) return;

    try {
      await ref.read(vaultAdminRepositoryProvider).deleteDraft(id);
      if (!mounted) return;
      if (_editingDraftId == id) setState(() => _editingDraftId = null);
    } catch (error) {
      if (!mounted) return;
      showAdminToast(
        context,
        message: 'تعذّر حذف المسودة',
        subtitle: error.toString(),
        kind: AdminToastKind.error,
      );
    }
  }

  /// -------------------------------------------------------------- layout ---
  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    final history =
        ref.watch(adminNotificationsStreamProvider).valueOrNull ??
        const <Map<String, dynamic>>[];
    final drafts =
        ref.watch(adminDraftsStreamProvider).valueOrNull ??
        const <Map<String, dynamic>>[];

    return SingleChildScrollView(
      padding: const EdgeInsets.fromLTRB(26, 18, 26, 40),
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 1380),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            _PageTabs(
              selected: _tab,
              historyCount: history.length,
              draftsCount: drafts.length,
              onSelect: (index) => setState(() => _tab = index),
            ),
            const SizedBox(height: 24),
            switch (_tab) {
              0 => _buildComposeTab(p),
              1 => _buildHistory(p),
              _ => _buildDrafts(p, drafts),
            },
          ],
        ),
      ),
    );
  }

  /// The mockups keep the assistant and the form side by side at full width,
  /// with the assistant column a hair wider; on narrow screens the assistant
  /// stacks first because it is where the copy comes from.
  Widget _buildComposeTab(AdminPalette p) {
    final isWide = MediaQuery.sizeOf(context).width >= 1150;
    final compose = _buildComposeCard(p);
    final assistant = AiAssistantPanel(onApplyToForm: _applyAiResult);

    if (!isWide) {
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [assistant, const SizedBox(height: 22), compose],
      );
    }

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(flex: 40, child: compose),
        const SizedBox(width: 22),
        Expanded(flex: 41, child: assistant),
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
      decoration: p.panel(shadow: true),
      clipBehavior: Clip.antiAlias,
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AdminCardHeading(
              icon: AdminIcons.edit,
              title: 'إنشاء إشعار جديد',
              subtitle: 'اكتب رسالتك، أو سيب الصياغة للمساعد',
              trailing: _FormStatusBadge(
                controllers: _copyControllers,
                fromAssistant: _draftFromAssistant,
                saved: _editingDraftId != null,
              ),
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(20, 17, 20, 16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _buildField(
                    controller: _titleArController,
                    label: 'عنوان الإشعار بالعربي',
                    hint: 'عنوان خفيف يلفت الانتباه',
                    maxLength: 60,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _messageArController,
                    label: 'الرسالة بالعربي',
                    hint: 'قولها بالمصري… وخليها تفتح النفس',
                    maxLines: 3,
                    maxLength: 180,
                  ),
                  const _LanguageSeparator(),
                  _buildField(
                    controller: _titleEnController,
                    label: 'عنوان الإشعار بالإنجليزي',
                    hint: 'A little title with a lot of flavor',
                    ltr: true,
                    maxLength: 60,
                  ),
                  const SizedBox(height: 12),
                  _buildField(
                    controller: _messageEnController,
                    label: 'الرسالة بالإنجليزي',
                    hint: 'Same good vibes, in English…',
                    maxLines: 3,
                    ltr: true,
                    maxLength: 180,
                  ),
                  const SizedBox(height: 20),
                  _buildSelectRow(p),
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
                      ltr: true,
                      validator: _validateCustomRoute,
                    ),
                  ],
                  const SizedBox(height: 14),
                  _buildRoutePreview(p, _resolveRoute(meals)),
                ],
              ),
            ),
            _buildFormActions(p),
          ],
        ),
      ),
    );
  }

  /// The tinted band the mockups close every card with: send on one side, the
  /// quieter draft save on the other.
  Widget _buildFormActions(AdminPalette p) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          Expanded(child: _buildSendButton(p)),
          const SizedBox(width: 10),
          TextButton.icon(
            onPressed: _savingDraft ? null : _saveDraft,
            icon: Icon(AdminIcons.save, size: 18, color: p.inkMuted),
            label: Text(
              _savingDraft ? 'جارٍ الحفظ…' : 'حفظ كمسودة',
              style: adminText(
                size: 13,
                weight: FontWeight.w500,
                color: p.inkMuted,
              ),
            ),
            style: TextButton.styleFrom(
              foregroundColor: p.inkMuted,
              backgroundColor: Colors.transparent,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 13),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AdminRadii.sm),
              ),
            ),
          ),
        ],
      ),
    );
  }

  /// Type and destination share one row of two dropdowns, the way the mockups
  /// group the two choices that decide what a broadcast is and where it lands.
  Widget _buildSelectRow(AdminPalette p) {
    final type = _types.firstWhere((t) => t.key == _selectedType);
    final destination = _destinations.firstWhere(
      (d) => d.key == _selectedDestination,
    );

    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Expanded(
          child: _buildSelect(
            label: 'نوع الإشعار',
            icon: type.icon,
            value: type.key,
            options: [
              for (final option in _types)
                (value: option.key, label: option.label, icon: option.icon),
            ],
            onChanged: (key) => setState(() => _selectedType = key),
          ),
        ),
        const SizedBox(width: 13),
        Expanded(
          child: _buildSelect(
            label: 'وجهة التوجيه',
            icon: destination.icon,
            value: destination.key,
            options: [
              for (final option in _destinations)
                (value: option.key, label: option.label, icon: option.icon),
            ],
            onChanged: (key) => setState(() {
              _selectedDestination = key;
              if (key != 'meal') _selectedMealId = null;
            }),
          ),
        ),
      ],
    );
  }

  Widget _buildSelect({
    required String label,
    required IconData icon,
    required String value,
    required List<({String value, String label, IconData icon})> options,
    required ValueChanged<String> onChanged,
  }) {
    final p = AdminPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabelRow(label: label),
        const SizedBox(height: 6),
        DropdownButtonFormField<String>(
          initialValue: value,
          isExpanded: true,
          dropdownColor: p.surface,
          menuMaxHeight: 340,
          borderRadius: BorderRadius.circular(AdminRadii.sm),
          icon: Icon(AdminIcons.expand, size: 18, color: p.inkFaint),
          style: adminText(size: 12.5, color: p.ink),
          decoration: adminFieldDeco(
            p,
            label: label,
            icon: icon,
            floatingLabel: false,
            fill: p.surface,
          ),
          items: [
            for (final option in options)
              DropdownMenuItem<String>(
                value: option.value,
                // The closed control already carries the picked option's glyph
                // as its prefix icon, so the menu list stays text-only.
                child: Text(
                  option.label,
                  overflow: TextOverflow.ellipsis,
                  style: adminText(size: 12.5, color: p.ink),
                ),
              ),
          ],
          onChanged: (next) {
            if (next != null) onChanged(next);
          },
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

  /// The mockups close the form with one quiet row instead of a third button:
  /// it opens the preview, and the chevron at the far end says there is
  /// somewhere to go without competing with send.
  Widget _buildRoutePreview(AdminPalette p, String route) {
    if (route.isEmpty) {
      return _TargetHint(
        icon: AdminIcons.link,
        text: 'لم تُحدَّد وجهة التوجيه بعد — أكملها قبل الإرسال.',
        palette: p,
      );
    }

    return InkWell(
      onTap: () => _showReview(p, route, allowSend: false),
      borderRadius: BorderRadius.circular(AdminRadii.sm),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 7),
        child: Row(
          children: [
            Icon(AdminIcons.visibility, size: 15, color: p.inkMuted),
            const SizedBox(width: 6),
            Expanded(
              child: Text(
                'شوف الإشعار زي ما هيظهر للمستخدم',
                style: adminText(size: 12, color: p.inkMuted, height: 1.5),
              ),
            ),
            Icon(AdminIcons.expand, size: 16, color: p.inkFaint),
          ],
        ),
      ),
    );
  }

  /// The push as the phone will paint it, with everything it carries next to
  /// it. [allowSend] is false when the row is opened just to look.
  Future<NotificationReviewResult?> _showReview(
    AdminPalette p,
    String route, {
    bool allowSend = true,
  }) {
    return showAdminDialog<NotificationReviewResult>(
      context: context,
      builder: (dialogContext) => AdminDialogShell(
        icon: AdminIcons.notifications,
        tone: AdminDialogTone.brand,
        title: 'معاينة الإشعار',
        subtitle: 'كده هتظهر رسالتك على موبايل المستخدم.',
        maxWidth: 760,
        child: NotificationReview(
          titleAr: _titleArController.text.trim(),
          messageAr: _messageArController.text.trim(),
          titleEn: _titleEnController.text.trim(),
          messageEn: _messageEnController.text.trim(),
          typeLabel: _typeStyle(p, _selectedType).label,
          route: route,
          allowSend: allowSend,
          onDecision: (decision) => Navigator.of(dialogContext).pop(decision),
        ),
      ),
    );
  }

  /// Send is a two-step action: the form is checked, then the review dialog is
  /// the place that actually commits — the same order the mockups use.
  Future<void> _reviewThenSend(AdminPalette p) async {
    if (!(_formKey.currentState?.validate() ?? false)) return;

    final meals = _selectedDestination == 'meal'
        ? (ref.read(vaultMealsStreamProvider).valueOrNull ??
              const <CloudMeal>[])
        : const <CloudMeal>[];
    final targetRoute = _resolveRoute(meals);
    if (targetRoute.isEmpty) {
      showAdminToast(
        context,
        message: 'أكمل وجهة التوجيه قبل الإرسال',
        kind: AdminToastKind.warning,
      );
      return;
    }

    final decision = await _showReview(p, targetRoute);
    if (decision != NotificationReviewResult.send || !mounted) return;
    await _sendNotification();
  }

  Widget _buildField({
    required TextEditingController controller,
    required String label,
    int maxLines = 1,
    bool ltr = false,
    String? hint,
    int? maxLength,
    String? Function(String?)? validator,
  }) {
    final p = AdminPalette.of(context);
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _FieldLabelRow(
          label: label,
          controller: controller,
          maxLength: maxLength,
        ),
        const SizedBox(height: 6),
        TextFormField(
          controller: controller,
          maxLines: maxLines,
          maxLength: maxLength,
          autovalidateMode: AutovalidateMode.onUserInteraction,
          style: ltr
              ? adminLatinText(size: 12.5, color: p.ink, height: 1.7)
              : adminText(size: 13, color: p.ink, height: 1.7),
          textDirection: ltr ? TextDirection.ltr : null,
          validator:
              validator ??
              (value) => (value == null || value.trim().isEmpty)
                  ? 'هذا الحقل مطلوب'
                  : null,
          decoration: adminFieldDeco(
            p,
            label: label,
            hint: hint,
            floatingLabel: false,
            counter: maxLength == null,
            fill: p.surface,
          ),
        ),
      ],
    );
  }

  Widget _buildSendButton(AdminPalette p) {
    return FilledButton(
      onPressed: _isSending ? null : () => _reviewThenSend(p),
      style: FilledButton.styleFrom(
        backgroundColor: p.claySolid,
        foregroundColor: p.onClay,
        disabledBackgroundColor: p.claySolid.withValues(alpha: 0.6),
        disabledForegroundColor: p.onClay.withValues(alpha: 0.7),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 13),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AdminRadii.sm),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (_isSending)
            SizedBox(
              width: 18,
              height: 18,
              child: CircularProgressIndicator(
                strokeWidth: 2.2,
                color: p.onClay,
              ),
            )
          else
            Icon(AdminIcons.campaign, size: 19, color: p.onClay),
          const SizedBox(width: 10),
          Text(
            _isSending ? 'جارٍ الإرسال…' : 'إرسال الإشعار',
            style: adminText(size: 13.5, weight: FontWeight.w600),
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
          return const _EmptyPanel(
            icon: AdminIcons.empty,
            title: 'أول إشعار هيبدأ الحكاية',
            body: 'أول إشعار ترسله سيظهر هنا مع تاريخ الإرسال ومن أرسله.',
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

  /// Drafts are the same record shape as the log, but every row hands the copy
  /// back to the compose tab instead of just showing it.
  Widget _buildDrafts(AdminPalette p, List<Map<String, dynamic>> drafts) {
    if (drafts.isEmpty) {
      return const _EmptyPanel(
        icon: AdminIcons.edit,
        title: 'كل الأفكار لسه في دماغك؟',
        body: 'المسودات بتتحفظ هنا، كمّلها وقت ما تحب وابعدها.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        for (final draft in drafts)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: _DraftCard(
              draft: draft,
              onOpen: () => _openDraft(draft),
              onDelete: () => _confirmDeleteDraft(draft),
            ),
          ),
      ],
    );
  }
}

/// ===========================================================================
/// Compose card helpers
/// ===========================================================================
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
              AdminIconChip(
                icon: AdminIcons.delete,
                tooltip: 'حذف',
                onTap: onDelete,
                glyphColor: p.chiliInk,
                glyphSize: 16,
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
        icon: AdminIcons.reminder,
        label: 'تذكير',
      );
    case 'update':
      return (
        bg: p.oliveSoft,
        fg: p.oliveInk,
        icon: AdminIcons.update,
        label: 'تحديث',
      );
    default:
      return (
        bg: p.honeySoft,
        fg: p.honeyInk,
        icon: AdminIcons.meal,
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

/// ===========================================================================
/// Page tabs
/// ===========================================================================
/// The three sections of this screen live on one underline tab bar: labels sit
/// on a shared hairline and only the active one gets an accent bar and colour,
/// so switching never moves the content width.
class _PageTabs extends StatelessWidget {
  final int selected;
  final int historyCount;
  final int draftsCount;
  final ValueChanged<int> onSelect;

  const _PageTabs({
    required this.selected,
    required this.historyCount,
    required this.draftsCount,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    return Container(
      decoration: BoxDecoration(
        border: Border(bottom: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          _tab(p, 0, AdminIcons.edit, 'إشعار جديد'),
          const SizedBox(width: 25),
          _tab(p, 1, AdminIcons.time, 'سجل الإشعارات', count: historyCount),
          const SizedBox(width: 25),
          _tab(p, 2, AdminIcons.save, 'المسودات', count: draftsCount),
        ],
      ),
    );
  }

  Widget _tab(
    AdminPalette p,
    int index,
    IconData icon,
    String label, {
    int? count,
  }) {
    final active = selected == index;
    final color = active ? p.onClaySoft : p.inkMuted;
    return InkWell(
      onTap: () => onSelect(index),
      child: IntrinsicWidth(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Padding(
              padding: const EdgeInsets.only(top: 6, bottom: 11),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(icon, size: 15, color: color),
                  const SizedBox(width: 8),
                  Text(
                    label,
                    style: adminText(
                      size: 13,
                      weight: active ? FontWeight.w600 : FontWeight.w500,
                      color: color,
                    ),
                  ),
                  if (count != null) ...[
                    const SizedBox(width: 8),
                    _TabCount(count: count),
                  ],
                ],
              ),
            ),
            Container(
              height: 2,
              decoration: BoxDecoration(
                color: active ? p.clay : Colors.transparent,
                borderRadius: BorderRadius.circular(3),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _TabCount extends StatelessWidget {
  final int count;

  const _TabCount({required this.count});

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    return Container(
      constraints: const BoxConstraints(minWidth: 18),
      padding: const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(4),
        border: Border.all(color: p.border),
      ),
      child: Text(
        count.toString().padLeft(2, '0'),
        textAlign: TextAlign.center,
        style: adminLatinText(size: 10.5, color: p.inkMuted),
      ),
    );
  }
}

/// ===========================================================================
/// Card chrome
/// ===========================================================================
/// The small chip in the compose card header that says what the form currently
/// holds: nothing, typed copy, an applied assistant draft, or a saved draft.
class _FormStatusBadge extends StatelessWidget {
  final List<TextEditingController> controllers;
  final bool fromAssistant;
  final bool saved;

  const _FormStatusBadge({
    required this.controllers,
    required this.fromAssistant,
    required this.saved,
  });

  @override
  Widget build(BuildContext context) {
    return ListenableBuilder(
      listenable: Listenable.merge(controllers),
      builder: (context, _) {
        final p = AdminPalette.of(context);
        final hasCopy = controllers.any((c) => c.text.trim().isNotEmpty);

        if (saved) {
          return _StatusChip(
            label: 'مسودة محفوظة',
            bg: p.honeySoft,
            border: p.honeySolid.withValues(alpha: 0.28),
            fg: p.honeyInk,
          );
        }
        if (fromAssistant) {
          return _StatusChip(
            label: 'من المساعد',
            bg: p.oliveSoft,
            border: p.oliveSolid.withValues(alpha: 0.28),
            fg: p.oliveInk,
            icon: AdminIcons.aiSparkle,
          );
        }
        if (hasCopy) {
          return _StatusChip(
            label: 'مسودة',
            bg: p.surfaceAlt,
            border: p.border,
            fg: p.inkMuted,
          );
        }
        return const SizedBox.shrink();
      },
    );
  }
}

class _StatusChip extends StatelessWidget {
  final String label;
  final Color bg;
  final Color border;
  final Color fg;
  final IconData? icon;

  const _StatusChip({
    required this.label,
    required this.bg,
    required this.border,
    required this.fg,
    this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(5),
        border: Border.all(color: border),
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
            style: adminText(size: 11, weight: FontWeight.w600, color: fg),
          ),
        ],
      ),
    );
  }
}

/// Marks where the English half of the form begins, the way the mockups split
/// a bilingual card without duplicating the field shapes.
class _LanguageSeparator extends StatelessWidget {
  const _LanguageSeparator();

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(0, 16, 0, 11),
      child: Row(
        children: [
          Text(
            'والحكاية بالإنجليزي',
            style: adminText(size: 11, color: p.inkFaint),
          ),
          const SizedBox(width: 8),
          Expanded(child: Container(height: 1, color: p.border)),
          const SizedBox(width: 8),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 2),
            decoration: BoxDecoration(
              color: p.surfaceSunken,
              borderRadius: BorderRadius.circular(3),
            ),
            child: Text(
              'EN',
              style: adminLatinText(
                size: 9.5,
                weight: FontWeight.w600,
                color: p.inkMuted,
                letterSpacing: 0.7,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Panel a list falls back to when it has nothing to show yet.
class _EmptyPanel extends StatelessWidget {
  final IconData icon;
  final String title;
  final String body;

  const _EmptyPanel({
    required this.icon,
    required this.title,
    required this.body,
  });

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
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
            child: Icon(icon, size: 28, color: p.inkFaint),
          ),
          const SizedBox(height: 16),
          Text(
            title,
            style: adminText(size: 15, weight: FontWeight.w600, color: p.ink),
          ),
          const SizedBox(height: 6),
          Text(
            body,
            style: adminText(size: 12.5, color: p.inkMuted, height: 1.6),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

/// One saved draft, with the two actions that matter: carry it back to the
/// compose tab, or drop it.
class _DraftCard extends StatelessWidget {
  final Map<String, dynamic> draft;
  final VoidCallback onOpen;
  final VoidCallback onDelete;

  const _DraftCard({
    required this.draft,
    required this.onOpen,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    final type = _typeStyle(p, draft['type'] as String?);
    final titleAr = (draft['titleAr'] as String? ?? '').trim();
    final messageAr = (draft['messageAr'] as String? ?? '').trim();
    final savedBy = (draft['savedBy'] as String? ?? 'admin').trim();
    final updatedAt = draft['updatedAt'];
    final when = updatedAt is Timestamp
        ? _formatSentAt(updatedAt)
        : 'جارٍ الحفظ…';

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
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        titleAr.isEmpty ? 'بدون عنوان' : titleAr,
                        style: adminText(
                          size: 15,
                          weight: FontWeight.w600,
                          color: p.ink,
                          height: 1.45,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    _TypePill(label: type.label, bg: type.bg, fg: type.fg),
                  ],
                ),
              ),
              AdminIconChip(
                icon: AdminIcons.delete,
                tooltip: 'حذف المسودة',
                onTap: onDelete,
                glyphColor: p.chiliInk,
                glyphSize: 16,
              ),
            ],
          ),
          if (messageAr.isNotEmpty) ...[
            const SizedBox(height: 10),
            Text(
              messageAr,
              style: adminText(size: 13.5, color: p.ink, height: 1.7),
            ),
          ],
          const SizedBox(height: 12),
          Row(
            children: [
              Icon(AdminIcons.time, size: 14, color: p.inkFaint),
              const SizedBox(width: 6),
              Text(when, style: adminLatinText(size: 11.5, color: p.inkMuted)),
              const SizedBox(width: 14),
              Icon(AdminIcons.person, size: 14, color: p.inkFaint),
              const SizedBox(width: 6),
              Expanded(
                child: Text(
                  savedBy,
                  overflow: TextOverflow.ellipsis,
                  textDirection: TextDirection.ltr,
                  style: adminLatinText(size: 11.5, color: p.inkMuted),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          FilledButton.tonalIcon(
            onPressed: onOpen,
            icon: Icon(AdminIcons.edit, size: 18, color: p.onClaySoft),
            label: Text(
              'كمّل المسودة دي',
              style: adminText(
                size: 13,
                weight: FontWeight.w600,
                color: p.onClaySoft,
              ),
            ),
            style: FilledButton.styleFrom(
              backgroundColor: p.claySoft,
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(AdminRadii.sm),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Label printed above a field: the name and its warm required mark hugging the
/// start edge, and the live character count sitting at the far end of the same
/// line — the mockups never park a counter under the box.
class _FieldLabelRow extends StatelessWidget {
  final String label;
  final TextEditingController? controller;
  final int? maxLength;

  const _FieldLabelRow({required this.label, this.controller, this.maxLength});

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);

    Widget row(String? count) => Row(
      children: [
        Flexible(
          child: Text(
            label,
            overflow: TextOverflow.ellipsis,
            style: adminText(
              size: 12.5,
              weight: FontWeight.w500,
              color: p.inkMuted,
              height: 1.4,
            ),
          ),
        ),
        const SizedBox(width: 4),
        Text(
          '*',
          style: adminLatinText(
            size: 13,
            weight: FontWeight.w600,
            color: p.honeyInk,
          ),
        ),
        const Spacer(),
        if (count != null)
          Text(
            count,
            // "12 / 60" is a Latin numeric run; without this the bidi algorithm
            // mirrors it to "60 / 12" inside the RTL row.
            textDirection: TextDirection.ltr,
            style: adminLatinText(size: 11, color: p.inkFaint),
          ),
      ],
    );

    if (controller == null || maxLength == null) return row(null);

    return ListenableBuilder(
      listenable: controller!,
      builder: (context, _) =>
          row('${controller!.text.characters.length} / $maxLength'),
    );
  }
}
