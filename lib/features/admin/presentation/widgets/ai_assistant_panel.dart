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
            padding: const EdgeInsets.all(20),
            decoration: p.panel(shadow: true),
            child: Column(
              mainAxisSize: fillsHeight ? MainAxisSize.max : MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _buildHeader(p, strings),
                const SizedBox(height: 22),
                if (fillsHeight)
                  Expanded(child: SingleChildScrollView(child: body))
                else
                  body,
                const SizedBox(height: 22),
                if (error != null) ...[
                  Text(
                    error,
                    style: adminText(size: 12, color: p.chiliInk, height: 1.7),
                  ),
                  const SizedBox(height: 12),
                ],
                AiPromptBar(
                  controller: _promptController,
                  focusNode: _focus,
                  providers: providers,
                  selectedTarget: _selectedTarget,
                  onTargetChanged: (target) =>
                      setState(() => _selectedTarget = target),
                  onSubmit: () => _handleGenerate(),
                  isGenerating: _isGenerating,
                ),
                const SizedBox(height: 12),
                _buildFootnotes(p, strings),
              ],
            ),
          ),
        );
      },
    );
  }

  /// ---------------------------------------------------------------- header ---
  Widget _buildHeader(AdminPalette p, AppStrings strings) {
    return Row(
      children: [
        Icon(AdminIcons.aiMagic, color: p.claySolid, size: 22),
        const SizedBox(width: 9),
        Text(
          strings.aiAssistantHeaderTitle,
          style: adminText(size: 16, weight: FontWeight.bold, color: p.ink),
        ),
        const SizedBox(width: 8),
        Text(
          strings.aiBadgeLabel,
          style: adminText(size: 10, color: p.inkMuted),
        ),
        const Spacer(),
        Text(
          _isGenerating ? strings.aiStatusBusy : strings.aiStatusReady,
          style: adminText(size: 10, color: p.inkMuted),
        ),
      ],
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
      padding: const EdgeInsets.symmetric(vertical: 45),
      child: Column(
        children: [
          // The panel is laid out inside a scroll view, so the spinner is given
          // its own slot instead of letting it drink the unbounded height.
          SizedBox(
            width: 48,
            height: 48,
            child: CircularProgressIndicator(color: p.claySolid),
          ),
          const SizedBox(height: 18),
          Text(
            strings.aiGeneratingTaste,
            style: adminText(size: 15, color: p.ink),
          ),
          const SizedBox(height: 8),
          TextButton(
            onPressed: _handleCancel,
            style: TextButton.styleFrom(foregroundColor: p.inkMuted),
            child: Text(
              strings.aiStopGenerating,
              style: adminText(size: 12.5, weight: FontWeight.w700),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildWelcome(AdminPalette p, AppStrings strings) {
    final ideas = [
      strings.aiChipKoshari,
      strings.aiChipRamadan,
      strings.aiChipReminder,
    ];

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 16),
      child: Column(
        children: [
          Container(
            width: 66,
            height: 66,
            alignment: Alignment.center,
            decoration: BoxDecoration(
              color: p.claySoft,
              borderRadius: BorderRadius.circular(AdminRadii.xl),
            ),
            child: Icon(AdminIcons.aiSparkle, size: 34, color: p.claySolid),
          ),
          const SizedBox(height: 18),
          Text(
            strings.aiWelcomeTitle,
            style: adminText(size: 20, weight: FontWeight.bold, color: p.ink),
          ),
          const SizedBox(height: 8),
          Text(
            strings.aiWelcomeSubtitle,
            textAlign: TextAlign.center,
            style: adminText(size: 12, color: p.inkMuted, height: 1.8),
          ),
          const SizedBox(height: 18),
          Wrap(
            spacing: 7,
            runSpacing: 7,
            alignment: WrapAlignment.center,
            children: [
              for (final idea in ideas)
                ActionChip(
                  label: Text(
                    idea,
                    style: adminText(size: 11, color: p.inkMuted),
                  ),
                  // Seeds the capsule instead of sending straight away, so the
                  // admin always edits the wording before paying a request.
                  onPressed: () {
                    _promptController.text = idea;
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
  Widget _buildFootnotes(AdminPalette p, AppStrings strings) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Text(
          strings.aiFooterPillars,
          textAlign: TextAlign.center,
          style: adminText(size: 10, color: p.inkMuted),
        ),
        const SizedBox(height: 8),
        Text(
          strings.aiFooterDisclaimer,
          textAlign: TextAlign.center,
          style: adminText(size: 10, color: p.inkFaint),
        ),
      ],
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
