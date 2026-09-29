import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../data/ai_notification_service.dart';
import '../../data/ai_provider_repository.dart';
import '../../data/models/ai_notification_result.dart';
import '../../data/models/ai_provider.dart';
import '../theme/admin_palette.dart';
import 'admin_dialog.dart';
import 'ai_prompt_bar.dart';
import 'ai_result_preview.dart';

/// ===========================================================================
/// AI assistant panel
///
/// The compose-side companion to the notification form: the admin writes an
/// idea, picks a model, and the panel previews the copy before pushing it into
/// the form through [onApplyToForm].
///
/// Provider configs stream from Firestore (`ai_providers`); the generated copy
/// comes from [AiNotificationService], which raises [AiServiceException] with
/// an Egyptian phrasing the admin can actually act on.
/// ===========================================================================
class AiAssistantPanel extends ConsumerStatefulWidget {
  /// Called when the admin taps "Apply to Form" on a generated result.
  /// The parent (NotificationManagementScreen) uses this to fill its controllers.
  final void Function(AiNotificationResult result) onApplyToForm;

  const AiAssistantPanel({super.key, required this.onApplyToForm});

  @override
  ConsumerState<AiAssistantPanel> createState() => _AiAssistantPanelState();
}

class _AiAssistantPanelState extends ConsumerState<AiAssistantPanel> {
  final _promptController = TextEditingController();

  AiProvider? _selectedProvider;
  AiNotificationResult? _lastResult;
  bool _isGenerating = false;
  String? _errorMessage;

  @override
  void dispose() {
    _promptController.dispose();
    super.dispose();
  }

  /// ------------------------------------------------------------- generate ---
    Future<void> _handleGenerate() async {
    final prompt = _promptController.text.trim();
    final providersAsync = ref.read(activeAiProvidersStreamProvider);
    final allProviders = providersAsync.value ?? [];
    if (prompt.isEmpty || allProviders.isEmpty || _isGenerating) return;

    FocusScope.of(context).unfocus();
    setState(() {
      _isGenerating = true;
      _errorMessage = null;
    });

    try {
      final result = await ref
          .read(aiNotificationServiceProvider)
          .generateNotification(targetProvider: _selectedProvider, allProviders: allProviders, userPrompt: prompt);
      if (!mounted) return;
      setState(() => _lastResult = result);
    } on AiServiceException catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = error.message);
    } catch (error) {
      if (!mounted) return;
      setState(() => _errorMessage = 'حدث خطأ: ');
    } finally {
      if (mounted) setState(() => _isGenerating = false);
    }
  }

  /// ---------------------------------------------------------------- apply ---
  void _applyToForm() {
    final result = _lastResult;
    if (result == null) return;

    widget.onApplyToForm(result);
    _showSnack(
      'تم ملء بيانات الإشعار من المساعد الذكي',
      AdminPalette.of(context).oliveSolid,
    );
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

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    final providersState = ref.watch(activeAiProvidersStreamProvider);
    final providers = providersState.valueOrNull ?? const <AiProvider>[];
    final result = _lastResult;
    final error = _errorMessage;

    // The panel is dropped both next to the form (bounded height) and under it
    // inside the screen's scroll view (unbounded), where an [Expanded] child
    // would blow up the layout.
    return LayoutBuilder(
      builder: (context, constraints) {
        final fillsHeight = constraints.hasBoundedHeight;

        return Container(
          padding: const EdgeInsets.all(16),
          decoration: p.panel(shadow: true),
          child: Column(
            mainAxisSize: fillsHeight ? MainAxisSize.max : MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              _buildPanelHeader(p),
              const SizedBox(height: 16),
              if (fillsHeight)
                Expanded(child: _buildChatArea(p, providers))
              else
                ConstrainedBox(
                  constraints: const BoxConstraints(maxHeight: 240),
                  child: _buildChatArea(p, providers),
                ),
              if (result != null) ...[
                const SizedBox(height: 12),
                AiResultPreview(result: result, onApply: _applyToForm),
              ],
              if (error != null) ...[
                const SizedBox(height: 12),
                _buildErrorBanner(p, error),
              ],
              const SizedBox(height: 12),
              AiPromptBar(
                controller: _promptController,
                providers: providers,
                selectedProvider: _selectedProvider,
                onProviderChanged: (provider) =>
                    setState(() => _selectedProvider = provider),
                onSubmit: _handleGenerate,
                isGenerating: _isGenerating,
              ),
            ],
          ),
        );
      },
    );
  }

  /// ---------------------------------------------------------------- header ---
  Widget _buildPanelHeader(AdminPalette p) {
    return Row(
      children: [
        Container(
          width: 42,
          height: 42,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: p.claySoft,
            borderRadius: BorderRadius.circular(AdminRadii.md),
          ),
          child: Icon(Icons.auto_fix_high_rounded, size: 21, color: p.clay),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                'مساعد الصياغة الذكي',
                style: adminText(
                  size: 15.5,
                  weight: FontWeight.bold,
                  color: p.ink,
                ),
              ),
              const SizedBox(height: 2),
              Text(
                'توليد صياغات مصرية جذابة للإشعارات',
                style: adminText(size: 12, color: p.inkMuted),
              ),
            ],
          ),
        ),
      ],
    );
  }

  /// ------------------------------------------------------------- chat area ---
  /// The status strip above the input: what the assistant is doing right now,
  /// or what it needs from the admin before it can do anything.
  Widget _buildChatArea(AdminPalette p, List<AiProvider> providers) {
    return SingleChildScrollView(
      padding: const EdgeInsets.only(bottom: 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (_isGenerating)
            _StatusLine(
              icon: Icons.hourglass_top_rounded,
              color: p.clay,
              bg: p.claySoft,
              text: 'جارٍ التوليد...',
              hint: 'الموديل يجهّز صياغة مصرية للإشعار.',
            )
          else if (_lastResult != null)
            _StatusLine(
              icon: Icons.check_circle_rounded,
              color: p.oliveInk,
              bg: p.oliveSoft,
              text: 'تم توليد الصياغة',
              hint: 'راجعها بالأسفل ثم اضغط «تطبيق في النموذج».',
            )
          else
            _buildIdleGuidance(p, providers),
        ],
      ),
    );
  }

  Widget _buildIdleGuidance(AdminPalette p, List<AiProvider> providers) {
    final providersState = ref.read(activeAiProvidersStreamProvider);

    if (providersState.hasError) {
      return _StatusLine(
        icon: AdminIcons.warning,
        color: p.chiliInk,
        bg: p.chiliSoft,
        text: 'تعذّر قراءة الموديلات',
        hint: 'تحقق من الاتصال أو من قواعد أمان Firestore.',
      );
    }
    if (providersState.isLoading) {
      return _StatusLine(
        icon: Icons.sync_rounded,
        color: p.inkMuted,
        bg: p.surfaceAlt,
        text: 'جارٍ تحميل الموديلات...',
        hint: 'نقرأ المزودين المفعّلين من Firebase.',
      );
    }
    if (providers.isEmpty) {
      return _StatusLine(
        icon: AdminIcons.empty,
        color: p.honeyInk,
        bg: p.honeySoft,
        text: 'لا يوجد موديلات ذكاء اصطناعي',
        hint: 'أضف مزودين في Firebase Console لتفعيل المساعد.',
      );
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          'إزاي تستخدم المساعد',
          style: adminText(
            size: 12,
            weight: FontWeight.w700,
            color: p.inkMuted,
          ),
        ),
        const SizedBox(height: 8),
        _TipRow(step: '1', text: 'اختر الموديل من الزر بالأسفل.', palette: p),
        _TipRow(
          step: '2',
          text: 'اكتب فكرة الإشعار: اسم أكلة، مناسبة، أو تذكير.',
          palette: p,
        ),
        _TipRow(
          step: '3',
          text: 'اضغط زر الإرسال، ثم طبّق النتيجة في النموذج.',
          palette: p,
        ),
      ],
    );
  }

  /// ---------------------------------------------------------- error banner ---
  Widget _buildErrorBanner(AdminPalette p, String message) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 10, 8, 10),
      decoration: BoxDecoration(
        color: p.chiliSoft,
        borderRadius: BorderRadius.circular(AdminRadii.md),
        border: Border.all(color: p.chiliSolid.withValues(alpha: 0.35)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AdminIcons.danger, size: 18, color: p.chiliInk),
          const SizedBox(width: 8),
          Expanded(
            child: Text(
              message,
              style: adminText(size: 12.5, color: p.chiliInk, height: 1.6),
            ),
          ),
          TextButton(
            onPressed: _isGenerating ? null : _handleGenerate,
            style: TextButton.styleFrom(
              foregroundColor: p.chiliInk,
              visualDensity: VisualDensity.compact,
              padding: const EdgeInsets.symmetric(horizontal: 8),
            ),
            child: Text(
              'جرب تاني',
              style: adminText(size: 12, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Status line
/// ---------------------------------------------------------------------------
class _StatusLine extends StatelessWidget {
  final IconData icon;
  final Color color;
  final Color bg;
  final String text;
  final String hint;

  const _StatusLine({
    required this.icon,
    required this.color,
    required this.bg,
    required this.text,
    required this.hint,
  });

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: bg,
        borderRadius: BorderRadius.circular(AdminRadii.md),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, size: 18, color: color),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  text,
                  style: adminText(
                    size: 13,
                    weight: FontWeight.w700,
                    color: p.ink,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  hint,
                  style: adminText(size: 11.5, color: p.inkMuted, height: 1.5),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Tip row
/// ---------------------------------------------------------------------------
class _TipRow extends StatelessWidget {
  final String step;
  final String text;
  final AdminPalette palette;

  const _TipRow({
    required this.step,
    required this.text,
    required this.palette,
  });

  @override
  Widget build(BuildContext context) {
    final p = palette;

    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 20,
            height: 20,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.claySoft,
              shape: BoxShape.circle,
            ),
            child: Text(
              step,
              style: adminText(
                size: 11,
                weight: FontWeight.w700,
                color: p.clay,
              ),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              text,
              style: adminText(size: 12.5, color: p.inkMuted, height: 1.6),
            ),
          ),
        ],
      ),
    );
  }
}
