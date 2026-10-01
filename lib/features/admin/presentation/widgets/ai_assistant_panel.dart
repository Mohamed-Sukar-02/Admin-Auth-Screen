import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/localization/app_strings.dart';
import '../../data/ai_notification_service.dart';
import '../../data/ai_provider_repository.dart';
import '../../data/models/ai_notification_result.dart';
import '../../data/models/ai_provider.dart';
import '../theme/admin_palette.dart';
import 'admin_dialog.dart';
import 'admin_toast.dart';
import 'ai_models_settings_dialog.dart';
import 'ai_prompt_bar.dart';

/// ===========================================================================
/// AI assistant panel
///
/// The compose-side companion to the notification form: the admin writes an
/// idea in the dark capsule at the bottom, picks a model, and the panel reads
/// back one of three states — a welcome when nothing has been generated yet, a
/// spinner that can be stopped mid-flight, or the bilingual draft itself.
///
/// Provider configs stream from Firestore (`ai_providers`); the generated copy
/// comes from [AiNotificationService], which raises [AiServiceException] with
/// an Egyptian phrasing the admin can actually act on.
/// ===========================================================================
class AiAssistantPanel extends ConsumerStatefulWidget {
  /// Called when the admin asks to push a draft into the compose form. The host
  /// confirms the swap when the form already holds text and answers with
  /// whether the fields were actually filled, so the button can latch.
  final Future<bool> Function(AiNotificationResult draft) onApplyToForm;

  const AiAssistantPanel({super.key, required this.onApplyToForm});

  @override
  ConsumerState<AiAssistantPanel> createState() => _AiAssistantPanelState();
}

class _AiAssistantPanelState extends ConsumerState<AiAssistantPanel> {
  final _promptController = TextEditingController();
  final _focus = FocusNode();

  AiSelectedTarget? _selectedTarget;
  AiNotificationResult? _currentResult;
  String _lastPrompt = '';
  bool _isGenerating = false;
  bool _isApplying = false;
  bool _isApplied = false;
  String? _errorMessage;

  /// Bumped on every "another variation" press so the offline fallback rotates
  /// to the next hand-written draft instead of replaying the same one.
  int _variant = 0;

  /// Cancel token. [AiNotificationService] has no way to abort the in-flight
  /// HTTP call, so stopping is done by invalidating the result: anything that
  /// comes back for a stale operation is dropped on the floor.
  int _operation = 0;

  @override
  void dispose() {
    _operation++;
    _promptController.dispose();
    _focus.dispose();
    super.dispose();
  }

  /// ------------------------------------------------------------- generate ---
  Future<void> _handleGenerate({bool again = false}) async {
    if (_isGenerating) return;
    final strings = AppStrings.of(context);
    final providers =
        ref.read(activeAiProvidersStreamProvider).valueOrNull ??
        const <AiProvider>[];
    final idea = (again ? _lastPrompt : _promptController.text).trim();

    if (idea.length < 2) {
      setState(() => _errorMessage = strings.aiIdeaTooShort);
      _focus.requestFocus();
      return;
    }
    if (providers.isEmpty) {
      setState(() => _errorMessage = strings.aiNoProviders);
      return;
    }

    final operation = ++_operation;
    final variation = again ? ++_variant : 0;
    FocusScope.of(context).unfocus();
    setState(() {
      _isGenerating = true;
      _isApplied = false;
      _errorMessage = null;
    });

    try {
      final result = await ref
          .read(aiNotificationServiceProvider)
          .generateNotification(
            target: _selectedTarget,
            allProviders: providers,
            userPrompt: idea,
            // A new idea edits the draft on screen ("خلّيها أقصر"); "صياغة
            // تانية" wants a clean take on the same idea, so it starts empty.
            previousDraft: again ? null : _currentResult,
            variant: variation,
          );
      if (!mounted || operation != _operation) return;
      setState(() {
        _currentResult = result;
        _lastPrompt = idea;
      });
    } on AiServiceException catch (error) {
      if (mounted && operation == _operation) {
        setState(() => _errorMessage = error.message);
      }
    } catch (error) {
      if (mounted && operation == _operation) {
        setState(() => _errorMessage = '${strings.errorOccurred}$error');
      }
    } finally {
      if (mounted && operation == _operation) {
        setState(() => _isGenerating = false);
      }
    }
  }

  /// --------------------------------------------------------------- cancel ---
  void _handleCancel() {
    _operation++;
    setState(() {
      _isGenerating = false;
      _errorMessage = null;
    });
  }

  /// ---------------------------------------------------------------- apply ---
  Future<void> _handleApply() async {
    final draft = _currentResult;
    if (draft == null || _isApplying || _isGenerating) return;
    final strings = AppStrings.of(context);

    setState(() => _isApplying = true);
    try {
      final applied = await widget.onApplyToForm(draft);
      if (!mounted) return;
      setState(() => _isApplied = applied);
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = strings.aiApplyFailed);
    } finally {
      if (mounted) setState(() => _isApplying = false);
    }
  }

  /// ----------------------------------------------------------------- copy ---
  Future<void> _handleCopy() async {
    final draft = _currentResult;
    if (draft == null) return;
    final strings = AppStrings.of(context);

    try {
      await Clipboard.setData(
        ClipboardData(
          text:
              '${draft.titleAr}\n${draft.messageAr}\n\n'
              '${draft.titleEn}\n${draft.messageEn}',
        ),
      );
      if (!mounted) return;
      showAdminToast(
        context,
        message: strings.aiCopiedToast,
        kind: AdminToastKind.success,
      );
    } catch (_) {
      if (!mounted) return;
      setState(() => _errorMessage = strings.aiCopyBlocked);
    }
  }

  /// --------------------------------------------------------------- layout ---
  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    final strings = AppStrings.of(context);
    final providers =
        ref.watch(activeAiProvidersStreamProvider).valueOrNull ??
        const <AiProvider>[];
    final customModels =
        ref.watch(customAiModelsStreamProvider).valueOrNull ??
        const <String, List<String>>{};
    final draft = _currentResult;
    final error = _errorMessage;

    // The panel is dropped both next to the form (bounded height) and under it
    // inside the screen's scroll view (unbounded), where an [Expanded] child
    // would blow up the layout.
    return LayoutBuilder(
      builder: (context, constraints) {
        final fillsHeight = constraints.hasBoundedHeight;
        final body = _buildBody(p, strings, draft);

        return Directionality(
          textDirection: TextDirection.rtl,
          child: Container(
            decoration: p.panel(shadow: true),
            clipBehavior: Clip.antiAlias,
            child: Column(
              mainAxisSize: fillsHeight ? MainAxisSize.max : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(p, strings),
                if (fillsHeight)
                  Expanded(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: body,
                    ),
                  )
                else
                  ConstrainedBox(
                    // The mockups hold the assistant body open at 318px so the
                    // card never collapses to a sliver next to the tall form.
                    constraints: const BoxConstraints(minHeight: 318),
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(20, 14, 20, 0),
                      child: body,
                    ),
                  ),
                Padding(
                  padding: const EdgeInsets.fromLTRB(20, 14, 20, 13),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      if (error != null) ...[
                        _buildErrorBanner(p, error),
                        const SizedBox(height: 11),
                      ],
                      AiPromptBar(
                        controller: _promptController,
                        focusNode: _focus,
                        providers: providers,
                        customModels: customModels,
                        selectedTarget: _selectedTarget,
                        onTargetChanged: (target) =>
                            setState(() => _selectedTarget = target),
                        onSubmit: () => _handleGenerate(),
                        isGenerating: _isGenerating,
                      ),
                      const SizedBox(height: 11),
                      _buildGuidelines(p, strings),
                    ],
                  ),
                ),
                _buildFooter(p, strings, providers.isEmpty),
              ],
            ),
          ),
        );
      },
    );
  }

  /// ---------------------------------------------------------------- header ---
  Widget _buildHeader(AdminPalette p, AppStrings strings) {
    return AdminCardHeading(
      icon: AdminIcons.aiSparkle,
      title: strings.aiAssistantHeaderTitle,
      subtitle: strings.aiAssistantSubtitle,
      trailing: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 5,
            height: 5,
            decoration: BoxDecoration(
              color: _isGenerating ? p.honeySolid : p.oliveSolid,
              shape: BoxShape.circle,
            ),
          ),
          const SizedBox(width: 5),
          Text(
            _isGenerating ? strings.aiStatusBusy : strings.aiStatusReady,
            style: adminText(size: 10.5, color: p.inkMuted),
          ),
          const SizedBox(width: 12),
          IconButton(
            onPressed: () => _openModelSettings(context),
            icon: Icon(AdminIcons.settings, size: 16, color: p.inkMuted),
            padding: EdgeInsets.zero,
            constraints: const BoxConstraints(),
            tooltip: 'إعدادات الموديلات',
          ),
        ],
      ),
    );
  }

  Future<void> _openModelSettings(BuildContext context) async {
    await showAdminDialog(
      context: context,
      builder: (context) => const AiModelsSettingsDialog(),
    );
  }

  /// ------------------------------------------------------------------ body ---
  Widget _buildBody(
    AdminPalette p,
    AppStrings strings,
    AiNotificationResult? draft,
  ) {
    if (_isGenerating) return _buildGenerating(p, strings);
    if (draft == null) return _buildWelcome(p, strings);
    return _buildResult(p, strings, draft);
  }

  Widget _buildGenerating(AdminPalette p, AppStrings strings) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 40),
      child: Column(
        children: [
          _PulseOrb(color: p.oliveSoft, glyph: p.oliveInk),
          const SizedBox(height: 26),
          Text(
            strings.aiGeneratingTaste,
            textAlign: TextAlign.center,
            style: adminText(size: 16, weight: FontWeight.w500, color: p.ink),
          ),
          const _StaggeredDots(),
          TextButton(
            onPressed: _handleCancel,
            style: TextButton.styleFrom(foregroundColor: p.inkMuted),
            child: Text(
              strings.aiStopGenerating,
              style: adminText(size: 12.5, weight: FontWeight.w600),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome(AdminPalette p, AppStrings strings) {
    final ideas = [
      (
        label: strings.aiChipKoshari,
        prompt: strings.aiChipKoshariPrompt,
        icon: AdminIcons.meal,
      ),
      (
        label: strings.aiChipRamadan,
        prompt: strings.aiChipRamadanPrompt,
        icon: AdminIcons.friday,
      ),
      (
        label: strings.aiChipReminder,
        prompt: strings.aiChipReminderPrompt,
        icon: AdminIcons.time,
      ),
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 10),
      child: Column(
        children: [
          const _AssistantArt(),
          const SizedBox(height: 14),
          Text(
            strings.aiWelcomeSubtitle,
            textAlign: TextAlign.center,
            style: adminText(size: 12, color: p.inkMuted, height: 1.85),
          ),
          const SizedBox(height: 19),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(width: 23, height: 1, color: p.border),
              const SizedBox(width: 9),
              Text(
                strings.aiIdeasLabel,
                style: adminText(size: 10.5, color: p.inkFaint),
              ),
              const SizedBox(width: 9),
              Container(width: 23, height: 1, color: p.border),
            ],
          ),
          const SizedBox(height: 9),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            alignment: WrapAlignment.center,
            children: [
              for (final idea in ideas)
                _SuggestionChip(
                  label: idea.label,
                  icon: idea.icon,
                  // Seeds the capsule with the full brief, not the chip's short
                  // name, and never sends — the admin edits before paying a
                  // request.
                  onTap: () {
                    _promptController.text = idea.prompt;
                    _promptController.selection = TextSelection.collapsed(
                      offset: idea.prompt.length,
                    );
                    _focus.requestFocus();
                  },
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildResult(
    AdminPalette p,
    AppStrings strings,
    AiNotificationResult draft,
  ) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildLanguageBlock(
          p,
          strings.aiEgyptianSection,
          draft.titleAr,
          draft.messageAr,
        ),
        const SizedBox(height: 16),
        _buildLanguageBlock(
          p,
          strings.aiEnglishSection,
          draft.titleEn,
          draft.messageEn,
          ltr: true,
        ),
        const SizedBox(height: 12),
        Text(
          '${strings.aiSuggestedType}: ${_localizedType(draft.type, strings)}',
          style: adminText(size: 11, color: p.inkMuted),
        ),
        const SizedBox(height: 16),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: _isApplying || _isGenerating ? null : _handleApply,
                style: FilledButton.styleFrom(
                  backgroundColor: p.claySolid,
                  foregroundColor: p.onClay,
                ),
                icon: _isApplying
                    ? SizedBox(
                        width: 15,
                        height: 15,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: p.onClay,
                        ),
                      )
                    : Icon(
                        _isApplied ? AdminIcons.check : AdminIcons.aiApply,
                        size: 17,
                      ),
                label: Text(
                  _isApplied ? strings.aiAppliedDraft : strings.aiApplyDraft,
                  style: adminText(size: 13, weight: FontWeight.w700),
                ),
              ),
            ),
            const SizedBox(width: 8),
            AdminIconChip(
              icon: AdminIcons.refresh,
              tooltip: strings.aiRegenerateTooltip,
              onTap: _isGenerating ? null : () => _handleGenerate(again: true),
            ),
            const SizedBox(width: 8),
            AdminIconChip(
              icon: AdminIcons.copy,
              tooltip: strings.aiCopyTooltip,
              onTap: _handleCopy,
            ),
          ],
        ),
      ],
    );
  }

  /// One language of the draft: a quiet caption, then the selectable copy, so
  /// the admin can lift a single line without going through the whole card.
  Widget _buildLanguageBlock(
    AdminPalette p,
    String label,
    String title,
    String message, {
    bool ltr = false,
  }) {
    return Directionality(
      textDirection: ltr ? TextDirection.ltr : TextDirection.rtl,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: adminText(size: 10, color: p.inkFaint)),
          const SizedBox(height: 5),
          SelectableText(
            title,
            style: adminText(size: 15, weight: FontWeight.w600, color: p.ink),
          ),
          const SizedBox(height: 5),
          SelectableText(
            message,
            style: adminText(size: 12, color: p.inkMuted, height: 1.8),
          ),
        ],
      ),
    );
  }

  /// ---------------------------------------------------------------- footers ---
  /// The line under the capsule: what the assistant promises, and the key that
  /// sends it — one quiet row instead of two centred paragraphs.
  Widget _buildGuidelines(AdminPalette p, AppStrings strings) {
    return Row(
      children: [
        Icon(AdminIcons.verified, size: 11, color: p.inkFaint),
        const SizedBox(width: 5),
        Expanded(
          child: Text(
            strings.aiFooterPillars,
            style: adminText(size: 10.5, color: p.inkFaint),
          ),
        ),
        Text('↵ Enter', style: adminLatinText(size: 10, color: p.inkFaint)),
      ],
    );
  }

  /// Card footer band: who owns the decision, and whether a provider is
  /// actually wired up behind the capsule.
  Widget _buildFooter(AdminPalette p, AppStrings strings, bool noProviders) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 11),
      decoration: BoxDecoration(
        border: Border(top: BorderSide(color: p.border)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              strings.aiFooterDisclaimer,
              style: adminText(size: 10.5, color: p.inkFaint),
            ),
          ),
          const SizedBox(width: 12),
          Icon(AdminIcons.settings, size: 13, color: p.inkMuted),
          const SizedBox(width: 5),
          Text(
            noProviders ? strings.aiOfflineMode : strings.aiOnlineMode,
            style: adminText(size: 10.5, color: p.inkMuted),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorBanner(AdminPalette p, String error) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: p.chiliSoft,
        borderRadius: BorderRadius.circular(AdminRadii.sm),
        border: Border.all(color: p.borderStrong),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(AdminIcons.warning, size: 15, color: p.chiliInk),
          const SizedBox(width: 6),
          Expanded(
            child: Text(
              error,
              style: adminText(size: 12, color: p.chiliInk, height: 1.8),
            ),
          ),
          InkWell(
            onTap: () => setState(() => _errorMessage = null),
            child: Icon(AdminIcons.close, size: 14, color: p.chiliInk),
          ),
        ],
      ),
    );
  }

  String _localizedType(String type, AppStrings strings) {
    return switch (type) {
      'reminder' => strings.aiTypeReminder,
      'update' => strings.aiTypeUpdate,
      _ => strings.aiTypeMeal,
    };
  }
}

/// ---------------------------------------------------------------------------
/// Welcome art
/// ---------------------------------------------------------------------------
/// The mockups open the assistant with a small illustration instead of a plain
/// icon: a fading dot grid, a dashed orbit, a tilted tile holding the wand, and
/// two speech bubbles — one Arabic, one the Latin letters. Everything is drawn
/// from tokens so it survives the dark library.
class _AssistantArt extends StatelessWidget {
  const _AssistantArt();

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    return SizedBox(
      width: 236,
      height: 121,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            child: CustomPaint(painter: _DotGridPainter(color: p.borderStrong)),
          ),
          Positioned(
            top: 12,
            left: 62,
            child: SizedBox(
              width: 112,
              height: 100,
              child: CustomPaint(painter: _DashedOvalPainter(color: p.border)),
            ),
          ),
          Positioned(
            top: 27,
            left: 85,
            child: Transform.rotate(
              angle: -10 * math.pi / 180,
              child: Container(
                width: 66,
                height: 66,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: p.oliveSoft,
                  borderRadius: BorderRadius.circular(AdminRadii.xl),
                  border: Border.all(color: p.borderStrong),
                ),
                child: Transform.rotate(
                  angle: 10 * math.pi / 180,
                  child: Icon(AdminIcons.aiMagic, size: 31, color: p.oliveInk),
                ),
              ),
            ),
          ),
          Positioned(
            top: 10,
            left: 19,
            child: _bubble(
              p,
              Transform.rotate(
                angle: -6 * math.pi / 180,
                child: Text(
                  'Aa',
                  style: adminLatinText(size: 14, color: p.inkFaint),
                ),
              ),
            ),
          ),
          Positioned(
            bottom: 12,
            right: 19,
            child: _bubble(
              p,
              Transform.rotate(
                angle: 7 * math.pi / 180,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(AdminIcons.notes, size: 17, color: p.inkFaint),
                    const SizedBox(width: 5),
                    Text(
                      AppStrings.of(context).aiEgyptianSection,
                      style: adminText(size: 10.5, color: p.inkFaint),
                    ),
                  ],
                ),
              ),
            ),
          ),
          Positioned(
            top: 8,
            right: 65,
            child: Icon(AdminIcons.aiSparkle, size: 15, color: p.inkFaint),
          ),
          Positioned(
            bottom: 21,
            left: 38,
            child: Icon(AdminIcons.add, size: 13, color: p.inkFaint),
          ),
        ],
      ),
    );
  }

  Widget _bubble(AdminPalette p, Widget child) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 7),
      decoration: BoxDecoration(
        color: p.surface,
        borderRadius: BorderRadius.circular(AdminRadii.md),
        border: Border.all(color: p.border),
      ),
      child: child,
    );
  }
}

class _DotGridPainter extends CustomPainter {
  final Color color;

  const _DotGridPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint();
    const step = 13.0;
    for (var y = step / 2; y < size.height; y += step) {
      for (var x = step / 2; x < size.width; x += step) {
        final dx = (x - size.width / 2) / (size.width / 2);
        final dy = (y - size.height / 2) / (size.height / 2);
        final distance = math.sqrt(dx * dx + dy * dy);
        if (distance >= 1) continue;
        paint.color = color.withValues(alpha: (1 - distance) * 0.85);
        canvas.drawCircle(Offset(x, y), 1, paint);
      }
    }
  }

  @override
  bool shouldRepaint(_DotGridPainter old) => old.color != color;
}

class _DashedOvalPainter extends CustomPainter {
  final Color color;

  const _DashedOvalPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 1
      ..strokeCap = StrokeCap.round;
    final path = Path()..addOval(Rect.fromLTWH(0, 0, size.width, size.height));
    for (final metric in path.computeMetrics()) {
      var distance = 0.0;
      while (distance < metric.length) {
        canvas.drawPath(metric.extractPath(distance, distance + 5), paint);
        distance += 9;
      }
    }
  }

  @override
  bool shouldRepaint(_DashedOvalPainter old) => old.color != color;
}

/// The tile that stands in for a spinner while a draft is being written: the
/// same rounded square as the welcome art, breathing a soft halo behind it.
class _PulseOrb extends StatefulWidget {
  final Color color;
  final Color glyph;

  const _PulseOrb({required this.color, required this.glyph});

  @override
  State<_PulseOrb> createState() => _PulseOrbState();
}

class _PulseOrbState extends State<_PulseOrb>
    with SingleTickerProviderStateMixin {
  late final AnimationController _pulse = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  )..repeat(reverse: true);

  @override
  void dispose() {
    _pulse.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _pulse,
      builder: (context, child) {
        final t = Curves.easeInOut.transform(_pulse.value);
        return SizedBox(
          width: 92,
          height: 92,
          child: Stack(
            alignment: Alignment.center,
            children: [
              Container(
                width: 68 + 10 * t,
                height: 68 + 10 * t,
                decoration: BoxDecoration(
                  color: widget.color.withValues(alpha: 0.45 - 0.2 * t),
                  borderRadius: BorderRadius.circular(AdminRadii.xl + 5),
                ),
              ),
              Transform.rotate(
                angle: (-5 + 11 * t) * math.pi / 180,
                child: Container(
                  width: 68,
                  height: 68,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: widget.color,
                    borderRadius: BorderRadius.circular(AdminRadii.xl),
                  ),
                  child: Icon(
                    AdminIcons.aiSparkle,
                    size: 30,
                    color: widget.glyph,
                  ),
                ),
              ),
            ],
          ),
        );
      },
    );
  }
}

class _StaggeredDots extends StatefulWidget {
  const _StaggeredDots();

  @override
  State<_StaggeredDots> createState() => _StaggeredDotsState();
}

class _StaggeredDotsState extends State<_StaggeredDots>
    with SingleTickerProviderStateMixin {
  late final AnimationController _tick = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1400),
  )..repeat();

  @override
  void dispose() {
    _tick.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    return AnimatedBuilder(
      animation: _tick,
      builder: (context, _) {
        return Padding(
          padding: const EdgeInsets.symmetric(vertical: 17),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              for (var i = 0; i < 3; i++)
                Container(
                  width: 5,
                  height: 5,
                  margin: const EdgeInsets.symmetric(horizontal: 2.5),
                  decoration: BoxDecoration(
                    color: p.oliveInk.withValues(
                      alpha: 0.35 + 0.65 * _brightness(i),
                    ),
                    shape: BoxShape.circle,
                  ),
                ),
            ],
          ),
        );
      },
    );
  }

  /// Each dot peaks a third of a cycle after the previous one.
  double _brightness(int index) {
    final phase = (_tick.value * 3 - index) % 3;
    return phase < 1 ? math.sin(phase * math.pi) : 0.0;
  }
}

/// Idea starter chip: quiet outline, icon, and a lift on press so it reads as
/// an offer rather than a button.
class _SuggestionChip extends StatelessWidget {
  final String label;
  final IconData icon;
  final VoidCallback onTap;

  const _SuggestionChip({
    required this.label,
    required this.icon,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(AdminRadii.sm),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 6),
        decoration: BoxDecoration(
          color: p.surface,
          borderRadius: BorderRadius.circular(AdminRadii.sm),
          border: Border.all(color: p.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 13, color: p.inkFaint),
            const SizedBox(width: 5),
            Text(label, style: adminText(size: 11.5, color: p.inkMuted)),
          ],
        ),
      ),
    );
  }
}
