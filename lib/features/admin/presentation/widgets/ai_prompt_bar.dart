import 'package:flutter/material.dart';

import '../../data/models/ai_provider.dart';
import '../theme/admin_palette.dart';
import 'admin_dialog.dart';

/// ===========================================================================
/// AI prompt bar
///
/// The chat-style input that sits at the bottom of the assistant panel: a
/// multi-line idea field on top, then the model selector pill and the circular
/// send button on the row underneath.
///
/// The controller belongs to the parent panel (it survives rebuilds and owns
/// the text), so this widget never disposes it.
/// ===========================================================================
class AiPromptBar extends StatelessWidget {
  final TextEditingController controller;
  final List<AiProvider> providers;
  final AiProvider? selectedProvider;
  final ValueChanged<AiProvider> onProviderChanged;
  final VoidCallback onSubmit;
  final bool isGenerating;

  const AiPromptBar({
    super.key,
    required this.controller,
    required this.providers,
    required this.selectedProvider,
    required this.onProviderChanged,
    required this.onSubmit,
    required this.isGenerating,
  });

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);

    return Container(
      decoration: BoxDecoration(
        color: p.surfaceAlt,
        borderRadius: BorderRadius.circular(AdminRadii.lg),
        border: Border.all(color: p.border),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 12, 10),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: controller,
            minLines: 1,
            maxLines: 4,
            textDirection: TextDirection.rtl,
            style: adminText(size: 13.5, color: p.ink, height: 1.6),
            decoration: InputDecoration(
              isDense: true,
              border: InputBorder.none,
              contentPadding: EdgeInsets.zero,
              hintText: 'اكتب فكرة الإشعار، اسم أكلة، أو مناسبة...',
              hintStyle: adminText(size: 13.5, color: p.inkFaint),
            ),
            onSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _ModelDropdownPill(
                providers: providers,
                selected: selectedProvider,
                onChanged: onProviderChanged,
              ),
              const Spacer(),
              _SendButton(
                onPressed: isGenerating ? null : onSubmit,
                isLoading: isGenerating,
              ),
            ],
          ),
        ],
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Model selector
/// ---------------------------------------------------------------------------
/// A pill showing the active model's name; tapping it opens the list of
/// providers that are enabled in Firestore.
class _ModelDropdownPill extends StatelessWidget {
  final List<AiProvider> providers;
  final AiProvider? selected;
  final ValueChanged<AiProvider> onChanged;

  const _ModelDropdownPill({
    required this.providers,
    required this.selected,
    required this.onChanged,
  });

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    final hasChoices = providers.isNotEmpty;

    return PopupMenuButton<AiProvider>(
      enabled: hasChoices,
      tooltip: 'اختر موديل',
      padding: const EdgeInsets.symmetric(vertical: 6),
      color: p.surface,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AdminRadii.md),
      ),
      onSelected: onChanged,
      itemBuilder: (context) => [
        for (final provider in providers)
          PopupMenuItem<AiProvider>(
            value: provider,
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        provider.name,
                        style: adminText(
                          size: 13,
                          weight: FontWeight.w700,
                          color: p.ink,
                        ),
                      ),
                      if (provider.rateLimit.isNotEmpty) ...[
                        const SizedBox(height: 2),
                        Text(
                          provider.rateLimit,
                          textDirection: TextDirection.ltr,
                          style: adminText(size: 11, color: p.inkFaint),
                        ),
                      ],
                    ],
                  ),
                ),
                if (provider.id == selected?.id) ...[
                  const SizedBox(width: 8),
                  Icon(Icons.check_rounded, size: 18, color: p.claySolid),
                ],
              ],
            ),
          ),
      ],
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          color: p.surfaceSunken,
          borderRadius: BorderRadius.circular(AdminRadii.pill),
          border: Border.all(color: p.border),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              Icons.auto_awesome_rounded,
              size: 14,
              color: hasChoices ? p.clay : p.inkFaint,
            ),
            const SizedBox(width: 6),
            Text(
              selected?.name ?? 'اختر موديل',
              style: adminText(
                size: 12,
                weight: FontWeight.w600,
                color: hasChoices ? p.inkMuted : p.inkFaint,
              ),
            ),
            const SizedBox(width: 4),
            Icon(
              Icons.keyboard_arrow_down_rounded,
              size: 16,
              color: p.inkMuted,
            ),
          ],
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Send action
/// ---------------------------------------------------------------------------
/// Circular send button that turns into a spinner while a request is in flight.
class _SendButton extends StatelessWidget {
  final VoidCallback? onPressed;
  final bool isLoading;

  const _SendButton({required this.onPressed, required this.isLoading});

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);

    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onPressed,
        customBorder: const CircleBorder(),
        child: Container(
          width: 36,
          height: 36,
          alignment: Alignment.center,
          decoration: BoxDecoration(
            color: isLoading ? p.claySoft : p.claySolid,
            shape: BoxShape.circle,
          ),
          child: isLoading
              ? SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: p.claySolid,
                  ),
                )
              : const Icon(
                  Icons.arrow_forward_rounded,
                  size: 18,
                  color: Colors.white,
                ),
        ),
      ),
    );
  }
}
