import 'package:flutter/material.dart';

import '../../../../core/localization/app_strings.dart';
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
  final AiSelectedTarget? selectedTarget;
  final ValueChanged<AiSelectedTarget?> onTargetChanged;
  final VoidCallback onSubmit;
  final bool isGenerating;

  const AiPromptBar({
    super.key,
    required this.controller,
    required this.providers,
    required this.selectedTarget,
    required this.onTargetChanged,
    required this.onSubmit,
    required this.isGenerating,
  });

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    final strings = AppStrings.of(context);

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
              hintText: strings.aiPromptHint,
              hintStyle: adminText(size: 13.5, color: p.inkFaint),
            ),
            onSubmitted: (_) => onSubmit(),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              _ModelDropdownPill(
                providers: providers,
                selected: selectedTarget,
                onChanged: onTargetChanged,
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
/// A pill showing the active target; tapping it opens a cascading menu where
/// every provider group flies out into the models it serves. The list of
/// groups is static ([_AiModelCatalog]) — the Firestore documents only supply
/// the API keys, so an empty collection just disables the picker.
class _ModelDropdownPill extends StatefulWidget {
  final List<AiProvider> providers;
  final AiSelectedTarget? selected;
  final ValueChanged<AiSelectedTarget?> onChanged;

  const _ModelDropdownPill({
    required this.providers,
    required this.selected,
    required this.onChanged,
  });

  @override
  State<_ModelDropdownPill> createState() => _ModelDropdownPillState();
}

class _ModelDropdownPillState extends State<_ModelDropdownPill> {
  final MenuController _menuController = MenuController();

  bool get _hasChoices => widget.providers.isNotEmpty;

  void _toggleMenu() {
    if (!_hasChoices) return;
    _menuController.isOpen ? _menuController.close() : _menuController.open();
  }

  /// Reserves the slot on every row so the labels stay aligned; an invisible
  /// tick would otherwise shift the text of the unselected items.
  Widget _checkIcon(bool isSelected, AdminPalette p) {
    return Icon(
      Icons.check_rounded,
      size: 18,
      color: isSelected ? p.claySolid : Colors.transparent,
    );
  }

  @override
  Widget build(BuildContext context) {
    final p = AdminPalette.of(context);
    final strings = AppStrings.of(context);
    final selected = widget.selected;

    return MenuAnchor(
      controller: _menuController,
      style: MenuStyle(
        backgroundColor: WidgetStatePropertyAll<Color>(p.surface),
        surfaceTintColor: WidgetStatePropertyAll<Color>(Colors.transparent),
        shadowColor: WidgetStatePropertyAll<Color>(p.shadow),
        elevation: WidgetStatePropertyAll<double>(12),
        shape: WidgetStatePropertyAll<OutlinedBorder>(
          RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AdminRadii.md),
          ),
        ),
        side: WidgetStatePropertyAll<BorderSide>(BorderSide(color: p.border)),
        padding: WidgetStatePropertyAll<EdgeInsetsGeometry>(
          const EdgeInsets.symmetric(horizontal: 6, vertical: 8),
        ),
      ),
      menuChildren: [
        MenuItemButton(
          leadingIcon: _checkIcon(selected == null, p),
          onPressed: () => widget.onChanged(null),
          child: Text(
            strings.aiAutoMode,
            style: adminText(size: 13, weight: FontWeight.w700, color: p.ink),
          ),
        ),
        Divider(height: 10, thickness: 1, color: p.border),
        for (final group in _AiModelCatalog.groups)
          SubmenuButton(
            leadingIcon: Icon(group.icon, size: 16, color: p.inkMuted),
            menuChildren: [
              for (final option in group.options)
                MenuItemButton(
                  leadingIcon: _checkIcon(
                    selected?.provider == group.provider &&
                        selected?.model == option.model,
                    p,
                  ),
                  onPressed: () => widget.onChanged(
                    AiSelectedTarget(
                      provider: group.provider,
                      model: option.model,
                      displayName: option.pillLabel ?? option.label,
                    ),
                  ),
                  child: Text(
                    option.label,
                    textDirection: TextDirection.ltr,
                    style: adminText(size: 12.5, color: p.ink),
                  ),
                ),
            ],
            child: Text(
              _AiModelCatalog.labelFor(strings, group.provider),
              style: adminText(size: 13, weight: FontWeight.w600, color: p.ink),
            ),
          ),
      ],
      child: Tooltip(
        message: strings.aiSelectModel,
        child: Material(
          color: Colors.transparent,
          borderRadius: BorderRadius.circular(AdminRadii.pill),
          child: InkWell(
            onTap: _toggleMenu,
            customBorder: const StadiumBorder(),
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
                    color: _hasChoices ? p.clay : p.inkFaint,
                  ),
                  const SizedBox(width: 6),
                  ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 190),
                    child: Text(
                      selected?.displayName ?? strings.aiAutoMode,
                      textDirection: selected == null
                          ? null
                          : TextDirection.ltr,
                      overflow: TextOverflow.ellipsis,
                      style: adminText(
                        size: 12,
                        weight: FontWeight.w600,
                        color: _hasChoices ? p.inkMuted : p.inkFaint,
                      ),
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
          ),
        ),
      ),
    );
  }
}

/// ---------------------------------------------------------------------------
/// Model catalog
/// ---------------------------------------------------------------------------
/// Provider key, icon and the models offered under it. Model ids and their
/// display names are product identifiers rather than copy, so they live here
/// and only the group heading goes through [AppStrings].
class _AiModelOption {
  final String model;
  final String label;

  /// Shown on the pill instead of [label] when the model name alone does not
  /// say which provider serves it.
  final String? pillLabel;

  const _AiModelOption({
    required this.model,
    required this.label,
    this.pillLabel,
  });
}

class _AiModelGroup {
  final String provider;
  final IconData icon;
  final List<_AiModelOption> options;

  const _AiModelGroup({
    required this.provider,
    required this.icon,
    required this.options,
  });
}

abstract final class _AiModelCatalog {
  static const List<_AiModelGroup> groups = [
    _AiModelGroup(
      provider: 'gemini',
      icon: Icons.bubble_chart_rounded,
      options: [
        _AiModelOption(model: 'gemini-1.5-flash', label: 'Gemini 1.5 Flash'),
        _AiModelOption(model: 'gemini-2.0-flash', label: 'Gemini 2.0 Flash'),
        _AiModelOption(model: 'gemini-1.5-pro', label: 'Gemini 1.5 Pro'),
      ],
    ),
    _AiModelGroup(
      provider: 'groq',
      icon: Icons.speed_rounded,
      options: [
        _AiModelOption(
          model: 'qwen/qwen3.8-27b',
          label: 'Qwen 3.8 27B',
          pillLabel: 'Groq: Qwen 3.8 27B',
        ),
        _AiModelOption(
          model: 'allam-2-7b',
          label: 'Allam 2 7B (علام)',
          pillLabel: 'Groq: Allam 2 7B (علام)',
        ),
        _AiModelOption(
          model: 'llama-3.3-70b-versatile',
          label: 'Llama 3.3 70B',
          pillLabel: 'Groq: Llama 3.3 70B',
        ),
      ],
    ),
    _AiModelGroup(
      provider: 'openrouter',
      icon: Icons.alt_route_rounded,
      options: [
        _AiModelOption(
          model: 'google/gemini-2.0-flash-exp:free',
          label: 'Gemini 2.0 Flash (Free)',
          pillLabel: 'OpenRouter: Gemini 2.0 Flash (Free)',
        ),
        _AiModelOption(
          model: 'meta-llama/llama-3-8b-instruct:free',
          label: 'Llama 3 8B (Free)',
          pillLabel: 'OpenRouter: Llama 3 8B (Free)',
        ),
      ],
    ),
  ];

  static String labelFor(AppStrings strings, String provider) {
    return switch (provider) {
      'gemini' => strings.aiProviderGoogle,
      'groq' => strings.aiProviderGroq,
      'openrouter' => strings.aiProviderOpenRouter,
      _ => provider,
    };
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
